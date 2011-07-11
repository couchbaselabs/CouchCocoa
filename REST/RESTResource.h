//
//  RESTResource.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/28/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class RESTCache, RESTOperation;


/** Represents an HTTP resource identified by a specific URL. */
@interface RESTResource : NSObject
{
    @private
    NSURL* _url;
    RESTResource* _parent;
    NSString* _relativePath;
    RESTCache* _owningCache;

    NSString* _eTag;
    NSString* _lastModified;
    id _representedObject;
    NSURL* _representedURL;
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

#pragma mark CONTENT:

/** The HTTP ETag of the last cached response. */
@property (copy) NSString* eTag;

/** The HTTP Last-Modified timestamp of the last cached response. */
@property (copy) NSString* lastModified;


/** Object representing the content of this resource.
    A client can store anything it wants here, such as a custom model object, or the result of parsing a JSON or XML response. */
@property (retain) id representedObject;

/** Convenience that calls -valueForKey: on the -representedObject.
    This is especially handy when the object is an NSDictionary. */
- (id) representedValueForKey: (NSString*)key;

/** Caches the parsed contents of a cacheable GET.
    If the operation is a successful GET, with a valid Etag: or Last-Modified: header, this method will set the representedObject, eTag and lastModified properties appropriately.
    @param representedObject  The application-specific object representing the contents of the response. (Or nil if you just want to set the eTag and lastModified.)
    @param operation  The GET operation that representedObject was parsed from.
    @return  YES if the response was cacheable and the object properties have been updated. */
- (BOOL) cacheRepresentedObject: (id)representedObject
                    forResponse: (RESTOperation*)operation;

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
    You can call this directly if you want to customize the NSMutableURLRequest and then create a RESTOperation object from it. */
- (NSMutableURLRequest*) requestWithMethod: (NSString*)method
                                parameters: (NSDictionary*)parameters;

#pragma mark PROTECTED:

/** This is sent by a RESTOperation when it completes, before its state changes or any other handlers are called.
    @param op  The RESTOperation, created by this object, that just completed.
    @param error  The error (or nil) result of the operation. This value has not yet been stored into the operation's -error property.
    @return  The error to store into the operation's -error property. You can return the input error value unchanged, or return a different (or no) error.*/
- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error;

/** Called when an untitled (URL-less) resource has just been created by a successful POST: call to its parent resource's URL.
    The base implementation sets this object's relativePath and URL properties based on the value of the response's Location: header. If you override this method, be sure to call the superclass method.
    @param op  The HTTP operation, which is actually a POST to the parent resource. */
- (void) createdByPOST: (RESTOperation*)op;

/** The URL of the last cached response.
    This is associated with the -eTag and -lastModified properties.
    This URL may not be the same as the receiver's -URL property, because "?"-prefixed parameters to a request are added to the URL's query. */
@property (retain) NSURL* representedURL;

@end
