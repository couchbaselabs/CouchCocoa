//
//  DemoQuery.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "DemoQuery.h"
#import "DemoItem.h"

#import "CouchCocoa.h"  // in a separate project you would use <CouchCocoa/CouchCocoa.h>


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
    NSLog(@"Reloading %lu rows from sequence #%lu...",
          (unsigned long)rows.count, (unsigned long)rows.sequenceNumber);
    NSMutableArray* entries = [NSMutableArray array];

    for (CouchQueryRow* row in rows) {
        DemoItem* item = [_modelClass itemForDocument: row.document];
        [entries addObject: item];
        // If this item isn't in the prior _entries, it's an external insertion:
        if (_entries && [_entries indexOfObjectIdenticalTo: item] == NSNotFound)
            [item markExternallyChanged];
    }

    if (![entries isEqual:_entries]) {
        NSLog(@"    ...entries changed!");
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
    NSLog(@"Updating the query...");
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
