//
//  DemoQuery.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "DemoQuery.h"
#import "DemoItem.h"

#import "Couch.h"
#import "RESTOperation.h"


@implementation DemoQuery


- (id) initWithQuery: (CouchQuery*)query
{
    NSParameterAssert(query);
    self = [super init];
    if (self != nil) {
        _modelClass = [DemoItem class];
        _query = [query retain];
        [self loadEntries];
        
        // Listen for external changes:
        _query.database.tracksChanges = YES;
        [[NSNotificationCenter defaultCenter] addObserver: self 
                                                 selector: @selector(updateEntries)
                                                     name: kCouchDatabaseChangeNotification 
                                                   object: nil];
    }
    return self;
}


- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [_entries release];
    [_query release];
    [super dealloc];
}


@synthesize modelClass=_modelClass;


- (void) loadEntriesFrom: (CouchQueryEnumerator*)rows {
    NSLog(@"Reloading entries...");
    NSMutableArray* entries = [NSMutableArray array];

    for (CouchQueryRow* row in rows) {
        DemoItem* item = [_modelClass itemForDocument: row.document];
        [entries addObject: item];
        // If this item isn't in the prior _entries, it's an external insertion:
        if (_entries && [_entries indexOfObjectIdenticalTo: item] == NSNotFound)
            [item markExternallyChanged];
    }

    if (![entries isEqual:_entries]) {
        [self willChangeValueForKey: @"entries"];
        [_entries release];
        _entries = [entries mutableCopy];
        [self didChangeValueForKey: @"entries"];
    }
}


- (void) loadEntries {
    _query.prefetch = (_entries == nil);        // for efficiency, include docs on first load
    [self loadEntriesFrom: [_query rows]];
}


- (BOOL) updateEntries {
    _query.prefetch = NO;   // prefetch disables rowsIfChanged optimization
    CouchQueryEnumerator* rows = [_query rowsIfChanged];
    if (!rows)
        return NO;
    [self loadEntriesFrom: rows];
    return YES;
}


#pragma mark -
#pragma mark ENTRIES PROPERTY:


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
