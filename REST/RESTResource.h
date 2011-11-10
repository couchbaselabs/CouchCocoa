//
//  RESTResource.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/28/11.
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
@class RESTCache, RESTOperation;


/** Represents an HTTP resource identified by a specific URL.
    RESTResource instances form a hierarchy. Root instances are instantiated with an explicit URL, and children with paths relative to their parents. Children know their parents, but parents don't automatically remember their children. (Subclasses can use the RESTCache utility to enable such downward links, however.)
*/
@interface RESTResource : NSObject
{
    @private
    NSURL* _url;
    RESTResource* _parent;
    NSString* _relativePath;
    RESTCache* _owningCache;
    NSMutableSet* _activeOperations;

    NSString* _eTag;
    NSString* _lastModified;
    NSURL* _cachedURL;
    
    NSURLCredential* _credential;
    NSURLProtectionSpace* _protectionSpace;
}

/** Creates an instance with an absolute URL and no parent. */
- (id) initWithURL: (NSURL*)url;

/** Creates an instance with a path relative to a parent.
    @param parent  The parent resource. May not be nil.
    @param path  The relative path from the parent. This is appended to the parent's URL, joined with a "/" if necessary. (In other words, the parent is assumed to be a container, so this never produces a sibling URL.) */
- (id) initWithParent: (RESTResource*)parent relativePath: (NSString*)path;

/** Creates an instance that has a parent but no URL yet.
    This resource will become real when it's first PUT, which will behind the scenes actually do a POST to the parent and assign the resource the URL returned in the Location: response header. */
- (id) initUntitledWithParent: (RESTResource*)parent;

@property (readonly) NSURL* URL;
@property (readonly) RESTResource* parent;

/** The relative path from the parent (as given in the initializer.) */
@property (readonly) NSString* relativePath;

/** Sets the login credential (e.g. username/password) to be used for authentication by this resource and its children. */
- (void) setCredential: (NSURLCredential*)credential;

/** Sets a protection space for operations on this resource. */
- (void) setProtectionSpace: (NSURLProtectionSpace*)protectionSpace;

#pragma mark HTTP METHODS:

/** Starts an asynchronous HTTP GET operation, with no parameters.
    (If you need to customize headers or URL queries, call -sendHTTP:parameters:.) */
- (RESTOperation*) GET;

/** Starts an asynchronous HTTP POST operation. */
- (RESTOperation*) POST: (NSData*)body parameters: (NSDictionary*)parameters;

/** Starts an asynchronous HTTP PUT operation.
    However, if this resource is "untitled" (has no relativePath yet), the operation will instead be a POST to the parent's URL. On successful completion of the POST, -createdByPOST: will be called, which will set the -relativePath property based on the response's Location: header. */
- (RESTOperation*) PUT: (NSData*)body parameters: (NSDictionary*)parameters;

/** Starts an asynchronous HTTP PUT operation, with a JSON body.
    The 'body' parameter will be serialized as JSON, and the Content-Type request header will be set to "application/json". */
- (RESTOperation*) PUTJSON: (id)body parameters: (NSDictionary*)parameters;

/** Starts an asynchronous HTTP POST operation, with a JSON body.
    The 'body' parameter will be serialized as JSON, and the Content-Type request header will be set to "application/json". */
- (RESTOperation*) POSTJSON: (id)body parameters: (NSDictionary*)parameters;

/** Starts an asynchronous HTTP DELETE operation. */
- (RESTOperation*) DELETE;

/** Sends an arbitrary HTTP request.
    All the other HTTP request methods ultimately call this one.
    @param method  The HTTP method, e.g. @"GET". Remember to capitalize it.
    @param parameters  Customization of the request headers or URL query.
    Parameters whose keys start with "?" will be added to the URL's query; others will be added to the HTTP headers. */
- (RESTOperation*) sendHTTP: (NSString*)method parameters: (NSDictionary*)parameters;

/** Creates an NSURLRequest without a RESTOperation.
    Called by -sendHTTP:parameters:.
    Clients usually won't need this, but you can call this directly if you want to customize the NSMutableURLRequest and then call -sendRequest: on it. */
- (NSMutableURLRequest*) requestWithMethod: (NSString*)method
                                parameters: (NSDictionary*)parameters;

/** Bottleneck for starting a RESTOperation.
    Clients usually won't need to call this. */
- (RESTOperation*) sendRequest: (NSURLRequest*)request;

#pragma mark CACHING:

/** Remembers the cacheable state (eTag and Last-Modified) of a GET response.
    If the operation is a successful GET, with a valid Etag: or Last-Modified: header, this method will set the eTag and lastModified properties appropriately. These will be then be sent in subsequent GET requests, which may then receive empty 304 (Not Modified) responses if the contents have not changed.
    @param operation  The GET operation that representedObject was parsed from; or nil to clear the cacheable state.
    @return  YES if the response was cacheable and the object properties have been updated. */
- (BOOL) cacheResponse: (RESTOperation*)operation;

/** The HTTP ETag of the last cached response. */
@property (copy) NSString* eTag;

/** The HTTP Last-Modified timestamp of the last cached response. */
@property (copy) NSString* lastModified;

/** The URL of the last cached response.
    This is associated with the -eTag and -lastModified properties.
    This URL might not be the same as the receiver's -URL property, because "?"-prefixed parameters to a request are added to the URL's query. */
@property (retain) NSURL* cachedURL;

#pragma mark TRACKING OPERATIONS:

/** If set to YES, the .activeOperations property is enabled. */
@property BOOL tracksActiveOperations;

/** All currently active RESTOperations on this resource or its children.
    This is not tracked (and will return nil) unless the .tracksActiveOperations property is first set to YES. */
@property (nonatomic, readonly) NSSet* activeOperations;

#pragma mark PROTECTED:

- (void) operationDidStart: (RESTOperation*)op;

- (void) operationDidComplete: (RESTOperation*)op;

/** This is sent by a RESTOperation to its resource when it completes, before its state changes or any other handlers are called.
    @param op  The RESTOperation, created by this object, that just completed.
    @param error  The error (or nil) result of the operation. This value has not yet been stored into the operation's -error property.
    @return  The error to store into the operation's -error property. You can return the input error value unchanged, or return a different (or no) error.*/
- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error;

/** Called when an untitled (URL-less) resource has just been created by a successful POST: call to its parent resource's URL.
    The base implementation sets this object's relativePath and URL properties based on the value of the response's Location: header. If you override this method, be sure to call the superclass method.
    @param op  The HTTP operation, which is actually a POST to the parent resource. */
- (void) createdByPOST: (RESTOperation*)op;

@end
