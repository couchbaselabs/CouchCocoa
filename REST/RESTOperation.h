//
//  RESTOperation.h
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

#import <Foundation/Foundation.h>
@class RESTBody, RESTResource;


/** Error domain used for HTTP errors (status >= 300). The code is the HTTP status. */
extern NSString* const CouchHTTPErrorDomain;


/** Type of block that's called when a RESTOperation completes (see -onComplete:). */
typedef void (^OnCompleteBlock)();


/** Represents an HTTP request to a RESTResource, and its response.
    Can be used either synchronously or asynchronously. Methods that return information about the
    response, such as -httpStatus or -body, will block if called before the response is available.
    Or you can explicitly block by calling -wait.
    On the other hand, to avoid blocking you can call -onCompletion: to schedule an Objective-C
    block to run when the response is complete. (Yes, the non-blocking mode takes a block... :) */
@interface RESTOperation : NSObject
{
    @private
    RESTResource* _resource;
    NSURLRequest* _request;
    NSURLConnection* _connection;
    SInt8 _state;
    UInt8 _retryCount;
    BOOL _waiting;
    NSError* _error;

    NSHTTPURLResponse* _response;
    NSMutableData* _body;
    id _resultObject;

    NSMutableArray* _onCompletes;
}

/** Initializes a RESTOperation, but doesn't start loading it yet.
    Call -load, -wait or any synchronous method to start it. */
- (id) initWithResource: (RESTResource*)resource request: (NSURLRequest*)request;

/** The RESTResource instance that created this operation. */
@property (readonly) RESTResource* resource;
/** The target URL of this operation. 
    (This is not necessarily the same as the URL of its resource! It's often the same, but it may have query parameters or sub-paths appended to it.) */
@property (readonly) NSURL* URL;
/** The last component of the URL's path. */
@property (readonly) NSString* name;
/** The HTTP method of the request. */
@property (readonly) NSString* method;
/** The underlying URL request. */
@property (readonly) NSURLRequest* request;

@property (readonly) BOOL isReadOnly;   /**< Is this a GET or HEAD request? */
@property (readonly) BOOL isGET;        /**< Is this a GET request? */
@property (readonly) BOOL isPUT;        /**< Is this a PUT request? */
@property (readonly) BOOL isPOST;       /**< Is this a POST request? */
@property (readonly) BOOL isDELETE;     /**< Is this a DELETE request? */

/** Sets an HTTP request header. Must be called before loading begins! */
- (void) setValue: (NSString*)value forHeader: (NSString*)headerName;

/** The HTTP request body. Cannot be changed after the operation starts. */
@property (copy) NSData* requestBody;

#pragma mark LOADING:

/** Sends the request, asynchronously. Subsequent calls do nothing.
    @return  The receiver (self), to make it easy to say "return [op start];". */
- (RESTOperation*) start;

/** Will call the given block when the request finishes.
    This method may be called multiple times; blocks will be called in the order added.
    @param onComplete  The block to be called when the request finishes.
    @return  YES if the block has been called by the time this method returns, NO if it will be called in the future. */
- (BOOL) onCompletion: (OnCompleteBlock)onComplete;

/** Blocks till any pending network operation finishes (i.e. -isComplete becomes true.)
    -start will be called if it hasn't yet been.
    On completion, any pending onCompletion blocks are called first, before this method returns.
    The synchronous methods below all end up calling this one.
    @return  YES on success, NO on error. */
- (BOOL) wait;

/** Blocks until all of the given operations have finished.
    @param operations  A set of RESTOperations.
    @return  YES if all operations succeeded; NO if any of them failed. */
+ (BOOL) wait: (NSSet*)operations;

/** Stops an active operation.
    The operation will immediately complete, with error NSURLErrorCancelled in domain NSURLErrorDomain.
    Has no effect if the operation has already completed. */
- (void) cancel;

#pragma mark RESPONSE:

/** YES if the response is complete (whether successful or unsuccessful.) */
@property (readonly) BOOL isComplete;

/** If the request has failed, this will be set to an NSError describing what went wrong; else it's nil.
    An HTTP response status of 300 or greater is considered an error and will cause this property to be set.
    This method does not block, but it won't be set to a non-nil value until the operation finishes. */
@property (readonly, retain) NSError* error;

/** YES if there is no error and the HTTP status is <= 299 (Synchronous.) */
@property (readonly) BOOL isSuccessful;

/** HTTP status code of the response (Synchronous.)
    Until the request finishes, this is zero. It's also zero if a lower-level network error occurred (like if the host couldn't be found or the TCP connection was reset.) */
@property (readonly) int httpStatus;

/** Dictionary of HTTP response headers (Synchronous.) */
@property (readonly) NSDictionary* responseHeaders;

/** The body of the response, with its entity headers (Synchronous.) */
@property (readonly) RESTBody* responseBody;


/** Object associated with this response.
    A client can store anything it wants here, typically a value parsed from or represented by the response body; often this property will be set by an onCompletion block. */
@property (retain) id resultObject;


/** Debugging utility that returns a sort-of log of the HTTP request and response. */
- (NSString*) dump;

@end



/** Levels of logging that RESTResponses can perform. */
typedef enum {
    kRESTLogNothing = 0,
    kRESTLogRequestURLs,
    kRESTLogRequestHeaders
} RESTLogLevel;

/** The current level of logging used by all RESTResponses. */
extern RESTLogLevel gRESTLogLevel;
