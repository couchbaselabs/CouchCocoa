//
//  DemoQuery.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class CouchQuery;


/** Simple controller for CouchDB demo apps.
    This class acts as glue between a CouchQuery (a CouchDB view) and an NSArrayController.
    The app can then bind its UI controls to the NSArrayController and get basic CRUD operations
    without needing any code. */
@interface DemoQuery : NSObject
{
    CouchQuery* _query;
    NSMutableArray* _entries;
    Class _modelClass;
}

- (id) initWithQuery: (CouchQuery*)query;

/** Class to instantiate for entries. Defaults to DemoItem. */
@property (assign) Class modelClass;

- (void) loadEntries;

- (BOOL) updateEntries;

/** The documents returned by the query, wrapped in DemoItem objects.
    An NSArrayController can be bound to this property. */
//@property (readonly) NSMutableArray* entries;

@end
