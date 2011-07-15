//
//  RESTResource.m
//  CouchCocoa
//
//  Created by Jens Alfke on 5/28/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "RESTResource.h"

#import "RESTInternal.h"
#import "RESTCache.h"
#import "JSONKit.h"


@implementation RESTResource


@synthesize parent=_parent, relativePath=_relativePath,
            cachedURL=_cachedURL;


- (id) initWithURL: (NSURL*)url {
    NSParameterAssert(url);
    self = [super init];
    if (self) {
        _url = [url retain];
    }
    return self;
}

- (id) initUntitledWithParent: (RESTResource*)parent {
    NSParameterAssert(parent);
    self = [super init];
    if (self) {
        _parent = [parent retain];
    }
    return self;
}

- (id) initWithParent: (RESTResource*)parent relativePath: (NSString*)path {
    NSParameterAssert(path);
    self = [self initUntitledWithParent: parent];
    if (self) {
        _relativePath = [path copy];
    }
    return self;
}

- (void) dealloc
{
    [_owningCache resourceBeingDealloced: self];
    [_eTag release];
    [_lastModified release];
    [_url release];
    [_relativePath release];
    [_parent release];
    [super dealloc];
}


- (RESTCache*) owningCache {
    return _owningCache;
}

- (void) setOwningCache:(RESTCache *)cache {
    NSAssert(!cache || !_owningCache, @"CouchDocument cannot belong to two caches");
    _owningCache = cache;
}


- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@]",
            [self class], (_url ? [_url absoluteString] : _relativePath)];
}


- (NSURL*) URL {
    if (_url)
        return _url;
    else if (_relativePath)
        return [_parent.URL URLByAppendingPathComponent: _relativePath];
    else
        return nil;
}


- (BOOL) isEqual:(id)object {
    if (object == self)
        return YES;
    if (!object || [object class] != [self class])
        return NO;
    RESTResource* other = object;
    if (_parent != other->_parent && ![_parent isEqual: other->_parent])
        return NO;
    return [_relativePath isEqualToString: other->_relativePath];
}


- (NSUInteger) hash {
    return [_parent hash] ^ [_relativePath hash];
}


#pragma mark -
#pragma mark HTTP METHODS:


- (NSMutableURLRequest*) requestWithMethod: (NSString*)method
                                parameters: (NSDictionary*)parameters
{
    NSMutableString* queries = nil;
    BOOL firstQuery;

    NSURL* url = self.URL;
    NSAssert1(url, @"Resource has no URL: %@", self);
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: url];
    request.HTTPMethod = method;
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    for (NSString* key in parameters) {
        NSString* value = [[parameters objectForKey: key] description];
        if ([key hasPrefix: @"?"]) {
            if (!queries) {
                queries = [NSMutableString string];
                firstQuery = (url.query.length == 0);
            }
            if (firstQuery) {
                [queries appendString: key];  // already includes leading '?'
                firstQuery = NO;
            } else {
                [queries appendString: @"&"];
                [queries appendString: [key substringFromIndex: 1]];
            }
            [queries appendString: @"="];
            value = [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            [queries appendString: value];
        } else {
            [request setValue: value forHTTPHeaderField: key];
        }
    }

    if (queries) {
        NSString* urlStr = [url.absoluteString stringByAppendingString: queries];
        request.URL = [NSURL URLWithString: urlStr];
    }

    return request;
}


- (RESTOperation*) sendRequest: (NSURLRequest*)request {
    return [[[RESTOperation alloc] initWithResource: self request: request] autorelease];
}


- (RESTOperation*) sendHTTP: (NSString*)method parameters: (NSDictionary*)parameters {
    NSMutableURLRequest* request = [self requestWithMethod: method parameters: parameters];

    // Conditional GET?
    if ([method isEqualToString: @"GET"] && [_cachedURL isEqual: request.URL]) {
        if (_eTag)
            [request setValue: _eTag forHTTPHeaderField: @"If-None-Match"];
        if (_lastModified)
            [request setValue: _lastModified forHTTPHeaderField: @"If-Modified-Since"];
    }

    return [self sendRequest: request];
}


- (RESTOperation*) GET {
    return [self sendHTTP: @"GET" parameters: nil];
}


- (RESTOperation*) POST: (NSData*)body
            parameters: (NSDictionary*)parameters
{
    NSMutableURLRequest* request = [self requestWithMethod: @"POST" parameters: parameters];
    if (body)
        [request setHTTPBody:body];
    return [self sendRequest: request];
}


- (void) createdByPOST: (RESTOperation*)op {
    NSString* location = [op.responseHeaders objectForKey: @"Location"];
    if (location) {
        NSURL* locationURL = [NSURL URLWithString: location relativeToURL: _parent.URL];
        if (locationURL) {
            _relativePath = [[locationURL lastPathComponent] copy];
            if (![self.URL isEqual: locationURL])
                _url = [locationURL retain];
        }
    }
}


- (RESTOperation*) PUT: (NSData*)body
           parameters: (NSDictionary*)parameters
{
    if (_relativePath) {
        NSMutableURLRequest* request = [self requestWithMethod: @"PUT" parameters: parameters];
        if (body)
            [request setHTTPBody:body];
        return [self sendRequest: request];

    } else {
        // If I have no URL yet, do a POST to my parent:
        RESTOperation* op = [self.parent POST: body parameters: parameters];
        [op onCompletion: ^{
            // ...then when done, use the Location: header of the result to generate my name/URL:
            if (!op.error) {
                [self createdByPOST: op];
            }
        }];
        return op;
    }
}


static NSDictionary* addJSONType(NSDictionary* parameters) {
    if ([parameters objectForKey: @"Content-Type"])
        return parameters;
    NSMutableDictionary* moreParams = parameters ? [parameters mutableCopy]
                                                 : [[NSMutableDictionary alloc] init];
    [moreParams setObject: @"application/json" forKey: @"Content-Type"];
    return [moreParams autorelease];
}


- (RESTOperation*) PUTJSON: (id)body parameters: (NSDictionary*)parameters {
    return [self PUT: [body JSONData]
          parameters: addJSONType(parameters)];
}


- (RESTOperation*) POSTJSON: (id)body parameters: (NSDictionary*)parameters {
    NSMutableURLRequest* request = [self requestWithMethod: @"POST"
                                                parameters: addJSONType(parameters)];
    [request setHTTPBody: [body JSONData]];
    return [self sendRequest: request];
}


- (RESTOperation*) DELETE {
    return [self sendHTTP: @"DELETE" parameters: nil];
}


#pragma mark -
#pragma mark CONTENT:


@synthesize eTag=_eTag, lastModified=_lastModified;


- (BOOL) cacheResponse: (RESTOperation*)op {
    if (op.isSuccessful && op.isGET) {
        NSString* eTag = [op.responseHeaders objectForKey: @"Etag"];
        NSString* lastModified = [op.responseHeaders objectForKey: @"Last-Modified"];
        if (eTag || lastModified) {
            self.eTag = eTag;
            self.lastModified = lastModified;
            self.cachedURL = op.URL;
            return YES;
        }
    } else if (op == nil) {
        self.eTag = nil;
        self.lastModified = nil;
        self.cachedURL = nil;
        return YES;
    }
    return NO;
}


#pragma mark -
#pragma mark CALLBACKS:


- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error {
    if (op.isGET) {
        if (op.httpStatus == 304) {
            error = nil;            // 304 Not Modified is not an error
        }
    }

    return error;
}


@end
