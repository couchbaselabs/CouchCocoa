//
//  RESTCookies.m
//  CouchCocoa
//
//  Created by David Venable on 1/19/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "RESTCookies.h"

@implementation RESTCookies

- (id)init
{
    self = [super init];
    {
        httpCookies = nil;
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
    [httpCookies release];
}

- (void)processRequest:(NSMutableURLRequest *)request
{
    request.HTTPShouldHandleCookies = NO;
    if(httpCookies != nil)
        [request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:httpCookies]];
}

- (void)processResponse:(NSHTTPURLResponse *)response
{
    httpCookies = [[NSHTTPCookie cookiesWithResponseHeaderFields:response.allHeaderFields forURL:response.URL] copy];
}

@end
