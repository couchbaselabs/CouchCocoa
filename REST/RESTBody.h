//
//  RESTBody.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/28/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class RESTResource;


/** An HTTP request/response body.
    Consists of a content blob, and a set of HTTP entity headers. */
@interface RESTBody : NSObject <NSMutableCopying>
{
    @protected
    NSData* _content;
    NSDictionary* _headers;
    RESTResource* _resource;
    id _fromJSON;
}

/** Returns a sub-dictionary of the input, containing only the HTTP 1.1 entity headers and their values. */
+ (NSDictionary*) entityHeadersFrom: (NSDictionary*)headers;

/** Initializes an instance with content and HTTP entity headers. */
- (id) initWithContent: (NSData*)content 
               headers: (NSDictionary*)headers
              resource: (RESTResource*)resource;

/** Initializes an instance with content and a Content-Type: header. */
- (id) initWithData: (NSData*)content contentType: (NSString*)contentType;

/** The raw content. */
@property (readonly, copy) NSData* content;

/** The HTTP headers, with standard capitalization (first letter of each word capitalized.) */
@property (readonly, copy) NSDictionary* headers;

/** The owning RESTResource. */
@property (readonly, retain) RESTResource* resource;

/** The value of the Content-Type: header. */
@property (readonly, copy) NSString* contentType;

/** The value of the Etag: header. */
@property (readonly, copy) NSString* eTag;

/** The value of the Last-Modified: header. */
@property (readonly, copy) NSString* lastModified;

/** Content parsed as string. */
@property (readonly) NSString* asString;

/** Parses the content as JSON and returns the result.
    This value is cached, so subsequent calls are cheap. */
@property (readonly) id fromJSON;

@end


/** A mutable subclass of RESTBody that allows the content and headers to be replaced. */
@interface RESTMutableBody : RESTBody

@property (readwrite, copy) NSData* content;
@property (readwrite, copy) NSDictionary* headers;
@property (readwrite, copy) NSMutableDictionary* mutableHeaders;
@property (readwrite, copy) NSString* contentType;
@property (readwrite, retain) RESTResource* resource;

@end


@interface RESTBody (JSON)
+ (NSData*) dataWithJSONObject: (id)obj;
+ (NSString*) stringWithJSONObject: (id)obj;
+ (id) JSONObjectWithData: (NSData*)data;
+ (id) JSONObjectWithString: (NSString*)string;
@end
