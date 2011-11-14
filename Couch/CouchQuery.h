//
//  CouchQuery.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/30/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CouchResource.h"
@class CouchDatabase, CouchDocument, CouchDesignDocument;
@class CouchLiveQuery, CouchQueryEnumerator, CouchQueryRow;


/** Represents a CouchDB 'view', or a view-like resource like _all_documents. */
@interface CouchQuery : CouchResource
{
    @private
    NSUInteger _limit, _skip;
    id _startKey, _endKey;
    BOOL _descending, _prefetch;
    NSArray *_keys;
    NSUInteger _groupLevel;
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

/** If non-zero, enables grouping of results, in views that have reduce functions. */
@property NSUInteger groupLevel;

/** If set to YES, the results will include the entire document contents of the associated rows.
    These can be accessed via CouchQueryRow's -documentContents property. */
@property BOOL prefetch;


/** Starts an asynchronous query of the CouchDB view.
    When complete, the operation's resultObject will be the CouchQueryEnumerator. */
- (RESTOperation*) start;

/** Sends the query to the server and returns an enumerator over the result rows (Synchronous). */
- (CouchQueryEnumerator*) rows;

/** Same as -rows, except returns nil if the query results have not changed since the last time it was evaluated (Synchronous). */
- (CouchQueryEnumerator*) rowsIfChanged;


/** Returns a live query with the same parameters. */
- (CouchLiveQuery*) asLiveQuery;

@end


/** A CouchQuery subclass that automatically refreshes the result rows every time the database changes.
    All you need to do is watch for changes to the .rows property. */
@interface CouchLiveQuery : CouchQuery
{
    @private
    BOOL _observing;
    RESTOperation* _op;
    CouchQueryEnumerator* _rows;
}

/** In CouchLiveQuery the -rows accessor is now a non-blocking property that can be observed using KVO. Its value will be nil until the initial query finishes. */
@property (readonly, retain) CouchQueryEnumerator* rows;

/** When the live query first starts, .rows will return nil until the initial results come back.
    This call will block until the results are ready. Subsequent calls do nothing. */
- (BOOL) wait;
@end


/** Enumerator on a CouchQuery's result rows.
    The objects returned are instances of CouchQueryRow. */
@interface CouchQueryEnumerator : NSEnumerator <NSCopying>
{
    @private
    CouchQuery* _query;
    NSArray* _rows;
    NSUInteger _totalCount;
    NSUInteger _nextRow;
    NSUInteger _sequenceNumber;
}

/** The number of rows returned in this enumerator */
@property (readonly) NSUInteger count;

/** The total number of rows in the query (excluding options like limit, skip, etc.) */
@property (readonly) NSUInteger totalCount;

/** The database's current sequenceNumber at the time the view was generated. */
@property (readonly) NSUInteger sequenceNumber;

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

/** The ID of the document described by this view row.
    (This is not necessarily the same as the document that caused this row to be emitted; see the discussion of the .sourceDocumentID property for details.) */
@property (readonly) NSString* documentID;

/** The ID of the document that caused this view row to be emitted.
    This is the value of the "id" property of the JSON view row.
    It will be the same as the .documentID property, unless the map function caused a related document to be linked by adding an "_id" key to the emitted value; in this case .documentID will refer to the linked document, while sourceDocumentID always refers to the original document. */
@property (readonly) NSString* sourceDocumentID;

/** The revision ID of the document this row was mapped from. */
@property (readonly) NSString* documentRevision;

/** The document this row was mapped from.
    This will be nil if a grouping was enabled in the query, because then the result rows don't correspond to individual documents. */
@property (readonly) CouchDocument* document;

/** The properties of the document this row was mapped from.
    To get this, you must have set the -prefetch property on the query; else this will be nil. */
@property (readonly) NSDictionary* documentProperties;

/** If this row's key is an array, returns the item at that index in the array.
    If the key is not an array, index=0 will return the key itself.
    If the index is out of range, returns nil. */
- (id) keyAtIndex: (NSUInteger)index;

/** Convenience for use in keypaths. Returns the key at the given index. */
@property (readonly) id key0, key1, key2, key3;

@end
