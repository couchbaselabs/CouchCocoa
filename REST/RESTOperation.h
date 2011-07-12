//
//  RESTOperation.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/26/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

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
    unsigned _state;
    NSError* _error;

    NSHTTPURLResponse* _response;
    NSMutableData* _body;
    id _resultObject;

    NSMutableArray* _onCompletes;
}

/** Initializes a RESTOperation, but doesn't start loading it yet.
    Call -load, -wait or any synchronous method to start it. */
- (id) initWithResource: (RESTResource*)resource request: (NSURLRequest*)request;

@property (readonly) RESTResource* resource;
@property (readonly) NSURL* URL;
@property (readonly) NSString* name;    // for documents this is the identifier
@property (readonly) NSString* method;
@property (readonly) NSURLRequest* request;

@property (readonly) BOOL isGET;
@property (readonly) BOOL isPUT;
@property (readonly) BOOL isPOST;
@property (readonly) BOOL isDELETE;

/** Sets an HTTP request header. Must be called before loading begins. */
- (void) setValue: (NSString*)value forHeader: (NSString*)headerName;

/** The HTTP request body. Cannot be changed after the operation starts. */
@property (copy) NSData* requestBody;

#pragma mark LOADING:

/** Sends the request, asynchronously. Subsequent calls do nothing.
    @return  YES if the resource is now loading, NO if it's not. */
- (BOOL) start;

/** Will call the given block when the request finishes.
    If it's already finished, it calls the block immediately (and returns YES).
    This method may be called multiple times; blocks will be called in the order added. */
- (BOOL) onCompletion: (OnCompleteBlock)onComplete;

/** Blocks till any pending network operation finishes (i.e. -isComplete becomes true.)
    -load will be called if it hasn't yet been.
    On completion, any pending onCompletion blocks are called first, before this method returns.
    The synchronous methods below all end up calling this one.
    @return  YES on success, NO on error. */
- (BOOL) wait;

#pragma mark RESPONSE:

/** YES if the response is complete (whether successful or unsuccessful.) */
@property (readonly) BOOL isComplete;

/** Status of the request; nil if everything's OK.
    This does not block, but it won't be set to a non-nil value until the operation finishes. */
@property (readonly, retain) NSError* error;

/** YES if there is no error and the HTTP status is <= 299. (Synchronous) */
@property (readonly) BOOL isSuccessful;

/** HTTP status code of the response. (Synchronous) */
@property (readonly) int httpStatus;

/** Dictionary of HTTP response headers. (Synchronous) */
@property (readonly) NSDictionary* responseHeaders;

/** The body of the response (data and entity headers). (Synchronous) */
@property (readonly) RESTBody* responseBody;


/** Object associated with this response.
    A client can store anything it wants here; often this property will be set by an onCompletion block. */
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
