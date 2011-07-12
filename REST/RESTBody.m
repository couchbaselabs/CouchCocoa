//
//  RESTBody.m
//  CouchCocoa
//
//  Created by Jens Alfke on 5/28/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "RESTBody.h"

#import "RESTInternal.h"
#import "JSONKit.h"


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
    if (!_fromJSON) {
#if TARGET_OS_IPHONE
        JSONDecoder* decoder = [[JSONDecoder alloc] init];
        _fromJSON = [[decoder objectWithData: _content] copy];
        [decoder release];
#else
        _fromJSON = [[_content objectFromJSONData] copy];
#endif
    }
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
