//
//  RESTBody.h
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
/** Converts an object to UTF-8-encoded JSON data.
    JSON 'fragments' (NSString / NSNumber) are allowed. Returns nil on nil input. */
+ (NSData*) dataWithJSONObject: (id)obj;
/** Converts an object to a JSON string.
    JSON 'fragments' (NSString / NSNumber) are allowed. Returns nil on nil input. */
+ (NSString*) stringWithJSONObject: (id)obj;
/** Parses JSON data into a Foundation object tree.
    If parsing fails, returns nil. */
+ (id) JSONObjectWithData: (NSData*)data;
/** Parses a JSON string into a Foundation object tree.
    If parsing fails, returns nil. */
+ (id) JSONObjectWithString: (NSString*)string;

/** Converts an NSDate to a string in ISO-8601 format (standard JSON representation). */
+ (NSString*) JSONObjectWithDate: (NSDate*)date;

/** Parses a string in ISO-8601 date format into an NSDate.
    Returns nil if the string isn't parseable, or if it isn't a string at all. */
+ (NSDate*) dateWithJSONObject: (id)jsonObject;

/** Encodes NSData to a Base64 string, which can be stored in JSON. */
+ (NSString*) base64WithData: (NSData*)data;

/** Decodes a Base64 string to NSData.
    Returns nil if the string is not valid Base64, or is not a string at all. */
+ (NSData*) dataWithBase64: (NSString*)base64;

@end
