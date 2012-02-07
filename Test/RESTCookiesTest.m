//
//  RESTCookiesTest.m
//  CouchCocoa
//
//  Created by David Venable on 2/6/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

#import "RESTCookies.h"

@interface RESTCookiesTest : SenTestCase
{
    RESTCookies *objectUnderTest;
    NSURL *aUrl;
    NSMutableDictionary *cookieProperties;
    NSString *cookieString;
}
@end

@implementation RESTCookiesTest

- (void)setUp
{
    objectUnderTest = [[RESTCookies alloc] init];
    
    aUrl = [[NSURL URLWithString:@"http://tempuri.org"] retain];
    STAssertNotNil(aUrl, nil);
    
    cookieProperties = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                         @"RESTCookieTest", NSHTTPCookieName,
                         @"Value", NSHTTPCookieValue,
                         @"tempuri.org", NSHTTPCookieDomain,
                         @"/some/where", NSHTTPCookiePath,
                         nil];
    cookieString = [NSString stringWithFormat:@"%@=%@",
                    [cookieProperties objectForKey:NSHTTPCookieName],
                    [cookieProperties objectForKey:NSHTTPCookieValue]];
}

- (void)tearDown
{
    [aUrl release];
    [objectUnderTest release];
    [cookieProperties release];
}

- (void)setCookieOnObjectUnderTest:(NSHTTPCookie *)cookie
{
    NSArray *cookies = [NSArray arrayWithObject:cookie];
    STAssertNoThrow([objectUnderTest setValue:cookies forKey:@"httpCookies"], nil);
}

- (void)test_ProcessRequestShouldSetHTTPShouldHandleCookiesToNo
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:aUrl];
    
    [objectUnderTest processRequest:request];
    
    STAssertFalse(request.HTTPShouldHandleCookies, nil);
}

- (void)test_ProcessRequestShouldSetHTTPShouldKeepExistingHeaders
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:aUrl];
    NSDictionary *existingHeaders = [NSDictionary dictionaryWithObjectsAndKeys:
                                     @"someValue", @"First-Header",
                                     @"anotherValue", @"Second-Header",
                                     nil];
    request.allHTTPHeaderFields = existingHeaders;
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
    STAssertNotNil(cookie, nil);
    [self setCookieOnObjectUnderTest:cookie];
    
    STAssertNoThrow([objectUnderTest processRequest:request], nil);

    for(id key in existingHeaders.allKeys) {
        STAssertTrue([request.allHTTPHeaderFields.allKeys containsObject:key], nil);
        STAssertEqualObjects([request.allHTTPHeaderFields objectForKey:key], [existingHeaders objectForKey:key], nil);
    }
}

- (void)test_ProcessRequestShouldSetCookiesWithEqualPath
{
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
    STAssertNotNil(cookie, nil);
    [self setCookieOnObjectUnderTest:cookie];
    
    NSURL *updatedUrl = [NSURL URLWithString:[cookieProperties objectForKey:NSHTTPCookiePath] relativeToURL:aUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:updatedUrl];
    
    STAssertNoThrow([objectUnderTest processRequest:request], nil);
    
    STAssertEquals(request.allHTTPHeaderFields.count, 1u, nil);
    NSString *cookies = [request.allHTTPHeaderFields objectForKey:@"Cookie"];
    STAssertEqualObjects(cookies, cookieString, nil);
}

- (void)test_ProcessRequestShouldSetCookiesWithMatchingSubPath
{
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
    STAssertNotNil(cookie, nil);
    [self setCookieOnObjectUnderTest:cookie];
    
    NSString *path = [NSString stringWithFormat:@"%@/%@", [cookieProperties objectForKey:NSHTTPCookiePath], @"more/paths"];
    NSURL *updatedUrl = [NSURL URLWithString:path relativeToURL:aUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:updatedUrl];
    
    STAssertNoThrow([objectUnderTest processRequest:request], nil);
    
    STAssertEquals(request.allHTTPHeaderFields.count, 1u, nil);
    NSString *cookies = [request.allHTTPHeaderFields objectForKey:@"Cookie"];
    STAssertEqualObjects(cookies, cookieString, nil);
}

- (void)test_ProcessRequestShouldIgnoreCookiesWithoutMatchingPath
{
    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:cookieProperties];
    STAssertNotNil(cookie, nil);
    [self setCookieOnObjectUnderTest:cookie];
    
    NSURL *updatedUrl = [NSURL URLWithString:@"some/path/of/its/own" relativeToURL:aUrl];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:updatedUrl];
    
    STAssertNoThrow([objectUnderTest processRequest:request], nil);
    
    STAssertEquals(request.allHTTPHeaderFields.count, 0u, nil);
}

@end
