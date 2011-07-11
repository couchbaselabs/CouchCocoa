//
//  DemoQuery.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class CouchQuery;


@interface DemoQuery : NSObject
{
    CouchQuery* _query;
    NSMutableArray* _entries;
}

- (id) initWithQuery: (CouchQuery*)query;

- (void) loadEntries;

- (BOOL) updateEntries;

// The property 'entries' is available by key-value coding.

@end
