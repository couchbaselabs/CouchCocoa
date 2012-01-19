//
//  RESTCookies.h
//  CouchCocoa
//
//  Created by David Venable on 1/19/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RESTCookies : NSObject
{
    NSMutableArray *httpCookies;
}

- (void)processRequest:(NSMutableURLRequest *)request;

- (void)processResponse:(NSHTTPURLResponse *)response;

@end
