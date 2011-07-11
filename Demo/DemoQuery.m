//
//  DemoQuery.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "DemoQuery.h"
#import "DemoItem.h"

#import "CouchServer.h"
#import "CouchDatabase.h"
#import "CouchQuery.h"
#import "RESTOperation.h"


@implementation DemoQuery


- (id) initWithQuery: (CouchQuery*)query
{
    NSParameterAssert(query);
    self = [super init];
    if (self != nil) {
        _query = query;
        [self loadEntries];
        _query.database.tracksChanges = YES;
        [_query.database onChange: ^(CouchDocument* doc) {[self updateEntries];}];
    }
    return self;
}


- (void) dealloc
{
    [_entries release];
    [_query release];
    [super dealloc];
}


- (void) loadEntriesFrom: (CouchQueryEnumerator*)rows {
    NSLog(@"Reloading entries...");
    NSMutableArray* entries = [NSMutableArray array];

    for (CouchQueryRow* row in [_query rows]) {
        DemoItem* item = [[DemoItem alloc] initWithDocument: row.document];
        [entries addObject: item];
        [item release];
    }

    [self willChangeValueForKey: @"entries"];
    _entries = [entries mutableCopy];
    [self didChangeValueForKey: @"entries"];
}


- (void) loadEntries {
    _query.prefetch = (_entries == nil);        // for efficiency, include docs on first load
    [self loadEntriesFrom: [_query rows]];
}


- (BOOL) updateEntries {
    CouchQueryEnumerator* rows = [_query rowsIfChanged];
    if (!rows)
        return NO;
    [self loadEntriesFrom: rows];
    return YES;
}


- (NSUInteger) countOfEntries {
    return _entries.count;
}


- (DemoItem*)objectInEntriesAtIndex: (NSUInteger)index {
    return [_entries objectAtIndex: index];
}


- (void) insertObject: (DemoItem*)object inEntriesAtIndex: (NSUInteger)index {
    [_entries insertObject: object atIndex: index];
    object.database = _query.database;
}


- (void) removeObjectFromEntriesAtIndex: (NSUInteger)index {
    DemoItem* item = [_entries objectAtIndex: index];
    item.database = nil;
    [_entries removeObjectAtIndex: index];
}


@end
