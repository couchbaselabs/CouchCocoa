//
//  RESTOperation.m
//  CouchCocoa
//
//  Created by Jens Alfke on 5/26/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "RESTOperation.h"

#import "RESTInternal.h"


/** Possible states that a RESTOperation is in during its lifecycle. */
typedef enum {
    kRESTObjectFailed = -1,
    kRESTObjectUnloaded,
    kRESTObjectLoading,
    kRESTObjectReady
} RESTOperationState;


NSString* const CouchHTTPErrorDomain = @"CouchHTTPError";

static NSString* const kRESTObjectRunLoopMode = @"RESTOperation";


RESTLogLevel gRESTLogLevel = kRESTLogNothing;


@interface RESTOperation ()
@property (readwrite, retain) NSError* error;
@end


@implementation RESTOperation


@synthesize resource=_resource, request=_request, error=_error;


- (id) initWithResource: (RESTResource*)resource request: (NSURLRequest*)request {
    NSParameterAssert(request != nil);
    self = [super init];
    if (self) {
        _resource = [resource retain];
        _request = [request mutableCopy];   // starts out mutable
        _state = kRESTObjectUnloaded;
    }
    return self;
}


- (void) dealloc {
    [_resultObject release];
    [_connection cancel];
    [_connection release];
    [_request release];
    [_error release];
    [_resource release];
    [super dealloc];
}


- (NSString*) description {
    static const char* const kNameOfState[4] = {"failed ", "", "loading ", "loaded "};
    return [NSString stringWithFormat: @"%@[%s %@ %@]",
            [self class], kNameOfState[_state - kRESTObjectFailed], self.method, self.URL];
}


- (NSURL*) URL {
    return _request.URL;
}

- (NSString*) name {
    return self.URL.lastPathComponent;
}

- (NSString*) method {
    return _request.HTTPMethod;
}

- (BOOL) isGET      {return [_request.HTTPMethod isEqualToString: @"GET"];}
- (BOOL) isPUT      {return [_request.HTTPMethod isEqualToString: @"PUT"];}
- (BOOL) isPOST     {return [_request.HTTPMethod isEqualToString: @"POST"];}
- (BOOL) isDELETE   {return [_request.HTTPMethod isEqualToString: @"DELETE"];}

- (BOOL) isReadOnly {
    NSString* method = _request.HTTPMethod;
    return [method isEqualToString: @"GET"] || [method isEqualToString: @"HEAD"];
}


- (NSString*) dump {
    NSMutableString* output = [NSMutableString stringWithFormat: @"\t%@ %@\n",
                                _request.HTTPMethod, _request.URL];
    NSDictionary* headers = _request.allHTTPHeaderFields;
    for (NSString* key in headers)
        [output appendFormat: @"\t%@: %@\n", key, [headers objectForKey: key]];
    if (_response) {
        [output appendFormat: @"\n\t%i %@\n",
             self.httpStatus, [NSHTTPURLResponse localizedStringForStatusCode: self.httpStatus]];
        headers = _response.allHeaderFields;
        for (NSString* key in headers)
            [output appendFormat: @"\t%@: %@\n", key, [headers objectForKey: key]];
    } else if (_error) {
        [output appendFormat: @"\n\tError: (%@, %i) %@\n",
            _error.domain, _error.code, _error.localizedDescription];
    }
    return output;
}


- (void) setValue: (NSString*)value forHeader: (NSString*)headerName {
    NSParameterAssert(_state == kRESTObjectUnloaded);
    [(NSMutableURLRequest*)_request setValue: value forHTTPHeaderField: headerName];
}


- (NSData*) requestBody {
    return _request.HTTPBody;
}

- (void) setRequestBody:(NSData *)requestBody {
    NSParameterAssert(_state == kRESTObjectUnloaded);
    ((NSMutableURLRequest*)_request).HTTPBody = requestBody;
}


#pragma mark LOADING:


- (void) _close {
    [_connection cancel];
    [_connection release];
    _connection = nil;

    [_body release];
    _body = nil;
}


- (BOOL) start {
    if (_state != kRESTObjectUnloaded)
        return NO;

    if (gRESTLogLevel >= kRESTLogRequestURLs) {
        NSLog(@"REST: >> %@ %@", _request.HTTPMethod, _request.URL);
        if (gRESTLogLevel >= kRESTLogRequestHeaders) {
            NSDictionary* headers = _request.allHTTPHeaderFields;
            for (NSString* key in headers)
                NSLog(@"REST:    %@: %@", key, [headers objectForKey: key]);
        }
    }

    _connection = [[NSURLConnection alloc] initWithRequest: _request
                                                  delegate: self
                                          startImmediately: NO];
    [_connection scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: NSRunLoopCommonModes];
    [_connection scheduleInRunLoop: [NSRunLoop currentRunLoop] forMode: kRESTObjectRunLoopMode];
    [_connection start];
    self.error = nil;
    _state = kRESTObjectLoading;
    return YES;
}


- (BOOL) wait {
    if (_state == kRESTObjectUnloaded)
        [self start];
    if (_connection && _state == kRESTObjectLoading) {
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        
        _waiting = YES;
        while (_connection && _state == kRESTObjectLoading) {
            if (![[NSRunLoop currentRunLoop] runMode: kRESTObjectRunLoopMode
                                          beforeDate: [NSDate distantFuture]])
                break;
        }
        _waiting = NO;

        if (gRESTLogLevel >= kRESTLogRequestURLs)
            NSLog(@"REST: Blocked for %.1f ms", (CFAbsoluteTimeGetCurrent() - start)*1000.0);
    }
    return _state == kRESTObjectReady;
}


- (BOOL) onCompletion: (OnCompleteBlock)onComplete {
    if (_state == kRESTObjectReady || _state == kRESTObjectFailed) {
        onComplete();  // call immediately if I've already finished
        return YES;
    } else {
        if (!_onCompletes)
            _onCompletes = [[NSMutableArray alloc] init];
        onComplete = [onComplete copy];
        [_onCompletes addObject: onComplete];
        [onComplete release];
        if (_state == kRESTObjectUnloaded)
            [self start];
        return NO;
    }
}


- (void) completedWithError: (NSError*)error {
    if (!_waiting &&
            [[[NSRunLoop currentRunLoop] currentMode] isEqualToString: kRESTObjectRunLoopMode]) {
        // If another RESTOperation is blocked in -wait, don't call out to client code until after
        // it finishes, because clients won't expect to get invoked re-entrantly.
        NSLog(@"RESTOperation: Deferring completion till other op finishes waiting");
        [self performSelector: _cmd withObject: error
                   afterDelay: 0.0 inModes: [NSArray arrayWithObject: NSRunLoopCommonModes]];
        return;
    }
    
    [_connection release];
    _connection = nil;
    
    _state = error ? kRESTObjectFailed : kRESTObjectReady;

    // Give my owning resource a chance to interpret the error:
    if (_resource)
        error = [_resource operation: self willCompleteWithError: error];

    if (gRESTLogLevel >= kRESTLogRequestHeaders) {
        if (error)
            NSLog(@"REST:    Error = %@", error.localizedDescription);
    }

    _state = error ? kRESTObjectFailed : kRESTObjectReady;
    self.error = error;

    NSArray* onCompletes = [_onCompletes autorelease];
    _onCompletes = nil;
    for (OnCompleteBlock onComplete in onCompletes)
        onComplete();
}


- (void) cancel {
    if (_state == kRESTObjectLoading || _state == kRESTObjectUnloaded) {
        [_connection cancel];
        [self completedWithError: [NSError errorWithDomain: NSURLErrorDomain
                                                      code: NSURLErrorCancelled
                                                  userInfo: nil]];
    }
}


#pragma mark -
#pragma mark RESPONSE:


- (int) httpStatus {
    [self wait]; // block till loaded
    return (int) _response.statusCode;
}


- (BOOL) isComplete {
    return (_state == kRESTObjectReady || _state == kRESTObjectFailed);
}


- (BOOL) isSuccessful {
    if (_state == kRESTObjectUnloaded || _state == kRESTObjectLoading)
        [self wait]; // block till complete
    return _state == kRESTObjectReady;
}


- (NSDictionary*) responseHeaders {
    [self wait]; // block till loaded
    return _response.allHeaderFields;
}


- (RESTBody*) responseBody {
    [self wait]; // block till loaded
    if (!_body)
        return nil;
    return [[[RESTBody alloc] initWithContent: _body 
                                  headers: [RESTBody entityHeadersFrom: _response.allHeaderFields]
                                 resource: _resource] autorelease];
}


- (id) resultObject {
    [self wait]; // block till loaded
    return _resultObject;
}


- (void) setResultObject: (id)object {
    if (object != _resultObject) {
        [_resultObject autorelease];
        _resultObject = [object retain];
    }
}


#pragma mark -
#pragma mark URL CONNECTION DELEGATE:


- (void)connection: (NSURLConnection*)connection didReceiveResponse: (NSURLResponse*)response {
    NSAssert(!_response, @"Got two responses?");
    _response = (NSHTTPURLResponse*) [response retain];
    // Don't check for HTTP error status yet; wait till response body is received since it may
    // contain detailed error info from the server.
}


- (void)connection: (NSURLConnection*)connection didReceiveData: (NSData*)data {
    if (!_body)
        _body = [data mutableCopy];
    else
        [_body appendData: data];
}


- (void)connectionDidFinishLoading: (NSURLConnection*)connection {
    NSInteger httpStatus = [_response statusCode];

    if (gRESTLogLevel >= kRESTLogRequestURLs) {
        NSLog(@"REST: << %ld for %@ %@ (%lu bytes)",
              (long)httpStatus, _request.HTTPMethod, _request.URL, (unsigned long)_body.length);
        if (gRESTLogLevel >= kRESTLogRequestHeaders) {
            NSDictionary* headers = _response.allHeaderFields;
            for (NSString* key in headers)
                NSLog(@"REST:    %@: %@", key, [headers objectForKey: key]);
        }
    }

    if (httpStatus < 300) {
        [self completedWithError: nil];
    } else {
        // Escalate HTTP error to a connection error:
        NSString* message = [NSHTTPURLResponse localizedStringForStatusCode:httpStatus];
        NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
                              message, NSLocalizedFailureReasonErrorKey,
                              [NSString stringWithFormat: @"%i %@", httpStatus, message],
                                NSLocalizedDescriptionKey,
                              self.URL, NSURLErrorKey,
                              nil];
        NSError* error = [NSError errorWithDomain: CouchHTTPErrorDomain
                                             code: httpStatus
                                         userInfo: info];
        [self completedWithError: error];
    }
}


- (void)connection: (NSURLConnection*)connection didFailWithError: (NSError*)error {
    [self completedWithError: error];
}


- (NSCachedURLResponse *)connection:(NSURLConnection *)connection 
                  willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return nil;
}


- (void)connection:(NSURLConnection *)connection 
    didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if (challenge.previousFailureCount == 0) {
        NSURLCredential* credential = [_resource credentialForOperation: self];
        NSLog(@"REST: Authentication challenge! credential=%@", credential);
        if (credential) {
            [challenge.sender useCredential: credential forAuthenticationChallenge: challenge];
            return;
        }
    }
    // give up
    [challenge.sender cancelAuthenticationChallenge: challenge];
}


@end
