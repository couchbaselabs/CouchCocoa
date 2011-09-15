//
//  RESTBody.m
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

#import "RESTBody.h"

#import "RESTInternal.h"
#import "RESTBase64.h"


@implementation RESTBody


@synthesize content = _content, headers = _headers, resource = _resource;


+ (NSDictionary*) entityHeadersFrom: (NSDictionary*)headers {
    static NSSet* kEntityHeaderNames;
    if (!kEntityHeaderNames) {
        // "HTTP: The Definitive Guide", pp.72-73
        kEntityHeaderNames = [[NSSet alloc] initWithObjects:
                              @"Allow", @"Location",
                              @"Content-Base", @"Content-Encoding", @"Content-Language",
                              @"Content-Length", @"Content-Location", @"Content-MD5",
                              @"Content-Range", @"Content-Type",
                              @"Etag", @"Expires", @"Last-Modified", nil];
    }
    
    NSMutableDictionary* entityHeaders = [NSMutableDictionary dictionary];
    for (NSString* headerName in headers) {
        if ([kEntityHeaderNames containsObject: headerName]) {
            [entityHeaders setObject: [headers objectForKey: headerName]
                              forKey: headerName];
        }
    }
    return (entityHeaders.count < headers.count) ? entityHeaders : headers;
}


// This is overridden by RESTMutableBody to make _headers a mutable copy.
- (void) setHeaders:(NSDictionary *)headers {
    if (headers != _headers) {
        [_headers release];
        _headers = [headers copy];
    }
}


- (id)init {
    self = [super init];
    if (self) {
        _content = [[NSData alloc] init];
        [self setHeaders: [NSDictionary dictionary]];
    }
    return self;
}


- (id) initWithContent: (NSData*)content 
               headers: (NSDictionary*)headers
              resource: (RESTResource*)resource
{
    NSParameterAssert(content);
    NSParameterAssert(headers);
    self = [super init];
    if (self) {
        _content = [content copy];
        [self setHeaders: headers];
    }
    return self;
}


- (id) initWithData: (NSData*)content contentType: (NSString*)contentType {
    return [self initWithContent: content
                         headers: [NSDictionary dictionaryWithObject: contentType
                                                              forKey: @"Content-Type"]
                        resource: nil];
}


- (void) dealloc
{
    [_content release];
    [_headers release];
    [_fromJSON release];
    [super dealloc];
}


- (id) copyWithZone:(NSZone *)zone {
    return [self retain];
}


- (id) mutableCopyWithZone:(NSZone *)zone {
    return [[RESTMutableBody alloc] initWithContent: _content
                                            headers: _headers
                                           resource: _resource];
}


- (BOOL) isEqual:(id)object {
    if (object == self)
        return YES;
    if (![object isKindOfClass: [RESTBody class]])
        return NO;
    return [_content isEqual: [object content]] && [_headers isEqual: [object headers]];
}

- (NSUInteger) hash {
    return _content.hash ^ _headers.hash;
}


- (NSString*) contentType   {return [_headers objectForKey:@"Content-Type"];}
- (NSString*) eTag          {return [_headers objectForKey:@"Etag"];}
- (NSString*) lastModified  {return [_headers objectForKey:@"Last-Modified"];}


- (NSString*) asString {
    NSStringEncoding encoding = NSUTF8StringEncoding;   //FIX: Get from _response.textEncodingName
    return [[[NSString alloc] initWithData: _content encoding: encoding] autorelease];
}


- (id) fromJSON {
    if (!_fromJSON)
        _fromJSON = [[RESTBody JSONObjectWithData: _content] copy];
    return _fromJSON;
}


@end




@implementation RESTMutableBody


- (NSData*) content {
    return _content;
}

- (void) setContent:(NSData *)content {
    if (content != _content) {
        [_content release];
        _content = [content copy];
        [_fromJSON release];
        _fromJSON = nil;
    }
}


- (NSDictionary*) headers {
    return [[_headers copy] autorelease];
}


- (void) setHeaders:(NSDictionary *)headers {
    if (headers != _headers) {
        [_headers release];
        _headers = [headers mutableCopy];
    }
}


- (NSMutableDictionary*) mutableHeaders {
    return (NSMutableDictionary*)_headers;
}


- (void) setMutableHeaders: (NSMutableDictionary*)headers {
    [self setHeaders: headers];
}


- (id) copyWithZone:(NSZone *)zone {
    return [[RESTBody alloc] initWithContent: _content headers: _headers resource: _resource];
}


- (NSString*) contentType   {return [_headers objectForKey:@"Content-Type"];}

- (void) setContentType: (NSString*)contentType {
    [self.mutableHeaders setObject: contentType forKey: @"Content-Type"];
}


- (RESTResource*) resource {
    return _resource;
}

- (void) setResource:(RESTResource *)resource {
    if (resource != _resource) {
        [_resource release];
        _resource = [resource retain];
    }
}


@end


#pragma mark JSON:


// Conditional compilation for JSONKit and/or NSJSONSerialization.
// If the app supports OS versions prior to NSJSONSerialization, we'll do a runtime
// test for it and use it if present, otherwise fall back to JSONKit.
#define USE_JSONKIT (MAC_OS_X_VERSION_MIN_REQUIRED < 1070 || __IPHONE_OS_VERSION_MIN_REQUIRED < 50000)

#if USE_JSONKIT
#import "JSONKit.h"
#endif

#if (MAC_OS_X_VERSION_MAX_ALLOWED < 1070 || __IPHONE_OS_VERSION_MAX_ALLOWED < 50000)
// Building against earlier SDK that doesn't contain NSJSONSerialization.h.
// So declare the necessary bits here (copied from the 10.7 SDK):
enum {
    NSJSONReadingMutableContainers = (1UL << 0),
    NSJSONReadingMutableLeaves = (1UL << 1),
    NSJSONReadingAllowFragments = (1UL << 2)
};
@interface NSJSONSerialization : NSObject
+ (NSData *)dataWithJSONObject:(id)obj options:(NSUInteger)opt error:(NSError **)error;
+ (id)JSONObjectWithData:(NSData *)data options:(NSUInteger)opt error:(NSError **)error;
@end
#endif


@implementation RESTBody (JSON)

#if USE_JSONKIT
static Class sJSONSerialization;

+ (void) initialize {
    if (self == [RESTBody class]) {
        sJSONSerialization = NSClassFromString(@"NSJSONSerialization");
    }
}
#else
#define sJSONSerialization NSJSONSerialization
#endif


+ (NSData*) dataWithJSONObject: (id)obj {
#if USE_JSONKIT
    if (!sJSONSerialization)
        return [obj JSONData];
#endif
    return [sJSONSerialization dataWithJSONObject: obj 
                                          options: NSJSONReadingAllowFragments
                                            error: NULL];
}

+ (NSString*) stringWithJSONObject: (id)obj {
#if USE_JSONKIT
    if (!sJSONSerialization)
        return [obj JSONString];
#endif
    NSData* data = [sJSONSerialization dataWithJSONObject: obj                                               
                                                  options: NSJSONReadingAllowFragments
                                                    error: NULL];
    if (!data)
        return nil;
    return [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
}


+ (id) JSONObjectWithData: (NSData*)data {
#if USE_JSONKIT
    if (!sJSONSerialization) {
#if TARGET_OS_IPHONE
        JSONDecoder* decoder = [[JSONDecoder alloc] init];
        id object = [decoder objectWithData: data];
        [decoder release];
        return object;
#else
        return [data objectFromJSONData];
#endif
    }
#endif
    
    return [sJSONSerialization JSONObjectWithData: data 
                                          options: 0
                                            error: NULL];
}

+ (id) JSONObjectWithString: (NSString*)string {
#if USE_JSONKIT
    if (!sJSONSerialization)
        return [string objectFromJSONString];
#endif
    NSData* data = [string dataUsingEncoding: NSUTF8StringEncoding];
    return [sJSONSerialization JSONObjectWithData: data 
                                          options: 0
                                            error: NULL];
}


+ (NSDateFormatter*) ISO8601Formatter {
    static NSDateFormatter* sFormatter;
    if (!sFormatter) {
        // Thanks to DenNukem's answer in http://stackoverflow.com/questions/399527/
        sFormatter = [[NSDateFormatter alloc] init];
        sFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
        sFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        sFormatter.calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar]
                                    autorelease];
        sFormatter.locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease];
    }
    return sFormatter;
}


+ (NSString*) JSONObjectWithDate: (NSDate*)date {
    return date ? [[self ISO8601Formatter] stringFromDate: date] : nil;
}

+ (NSDate*) dateWithJSONObject: (id)jsonObject {
    NSString* string = $castIf(NSString, jsonObject);
    return string ? [[self ISO8601Formatter] dateFromString: string] : nil;
}


+ (NSString*) base64WithData: (NSData*)data {
    return [RESTBase64 encode: data];
}


+ (NSData*) dataWithBase64: (NSString*)base64 {
    return [RESTBase64 decode: base64];
}


@end