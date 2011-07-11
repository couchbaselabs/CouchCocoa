//
//  CouchQuery.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/30/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchResource.h"
@class CouchDatabase;
@class CouchDocument;
@class CouchDesignDocument;
@class CouchQueryEnumerator;
@class CouchQueryRow;


/** Represents a CouchDB 'view', or a view-like resource like _all_documents. */
@interface CouchQuery : CouchResource
{
    @private
    NSUInteger _limit, _skip;
    id _startKey, _endKey;
    BOOL _descending, _prefetch;
    NSArray *_keys;
}

/** The design document that contains this view. */
@property (readonly) CouchDesignDocument* designDocument;

/** The maximum number of rows to return. Default value is 0, meaning 'unlimited'. */
@property NSUInteger limit;

/** The number of initial rows to skip. Default value is 0.
    Should only be used with small values. For efficient paging, use startkey and limit.*/
@property NSUInteger skip;

/** Should the rows be returned in descending key order? Default value is NO. */
@property BOOL descending;

/** If non-nil, the key value to start at. */
@property (copy) id startKey;

/** If non-nil, the key value to end after. */
@property (copy) id endKey;

/** If non-nil, the query will fetch only the rows with the given keys. */
@property (copy) NSArray* keys;

/** If set to YES, the results will include the entire document contents of the associated rows.
    These can be accessed via CouchQueryRow's -documentContents property. */
@property BOOL prefetch;


/** Sends the query to the server and returns an enumerator over the result rows.
    This is currently synchronous (blocks until the response is complete) but may not remain so. */
- (CouchQueryEnumerator*) rows;

/** Same as -rows, except returns nil if the query results have not changed since the last time
    it was evaluated. (Synchronous) */
- (CouchQueryEnumerator*) rowsIfChanged;

@end


/** Enumerator on a CouchQuery's result rows.
    The objects returned are instances of CouchQueryRow. */
@interface CouchQueryEnumerator : NSEnumerator
{
    @private
    CouchQuery* _query;
    NSArray* _rows;
    NSUInteger _totalCount;
    NSUInteger _nextRow;
}

/** The number of rows returned in this enumerator */
@property (readonly) NSUInteger count;

/** The total number of rows in the query (excluding options like limit, skip, etc.) */
@property (readonly) NSUInteger totalCount;

/** The next result row. This is the same as -nextObject but with a checked return type. */
- (CouchQueryRow*) nextRow;

/** Random access to a row in the result */
- (CouchQueryRow*) rowAtIndex: (NSUInteger)index;

@end


/** A result row from a CouchDB view query. */
@interface CouchQueryRow : NSObject
{
    @private
    CouchQuery* _query;
    id _result;
}

@property (readonly) CouchQuery* query;
@property (readonly) id key;
@property (readonly) id value;

/** The document this row was mapped from. */
@property (readonly) CouchDocument* document;

/** The contents of the document this row was mapped from.
    To get this, you must have set the -prefetch property on the query; else this will be nil. */
@property (readonly) NSDictionary* documentContents;

@end
