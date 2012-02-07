//
//  RESTCookies.m
//  CouchCocoa
//
//  Created by David Venable on 1/19/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "RESTCookies.h"

@interface RESTCookies()
- (void)addSessionCookies:(NSArray *)newCookies;
- (void)addSessionCookie:(NSHTTPCookie *)newCookie;
@end


@implementation RESTCookies

- (id)init
{
    self = [super init];
    {
        _httpCookies = [[NSMutableArray array] retain];
    }
    return self;
}

- (void)dealloc
{
    [_httpCookies release];
    [super dealloc];
}

- (void)processRequest:(NSMutableURLRequest *)request
{
    request.HTTPShouldHandleCookies = NO;
    [request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:_httpCookies]];
}

- (void)processResponse:(NSHTTPURLResponse *)response
{
    [self addSessionCookies:[NSHTTPCookie cookiesWithResponseHeaderFields:response.allHeaderFields forURL:response.URL]];
}

#pragma mark -
#pragma mark Extension Messages

- (void)addSessionCookies:(NSArray *)newCookies
{
    for(NSHTTPCookie *cookie in newCookies)
    {
        [self addSessionCookie:cookie];
    }
}

- (void)addSessionCookie:(NSHTTPCookie *)newCookie
{
	NSHTTPCookie *cookie;
	NSUInteger i;
	NSUInteger numberOfCookies = [_httpCookies count];
	for (i = 0; i < numberOfCookies; i++) {
		cookie = [_httpCookies objectAtIndex:i];
		if ([[cookie domain] isEqualToString:[newCookie domain]] &&
            [[cookie path] isEqualToString:[newCookie path]] &&
            [[cookie name] isEqualToString:[newCookie name]])
        {
			[_httpCookies removeObjectAtIndex:i];
			break;
		}
	}
    [_httpCookies addObject:newCookie];
}

@end
