//
//  CouchQuery.m
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

// <http://wiki.apache.org/couchdb/HTTP_view_API#Querying_Options>
// <http://wiki.apache.org/couchdb/Introduction_to_CouchDB_views>


#import "CouchQuery.h"
#import "CouchDesignDocument.h"
#import "CouchInternal.h"


@interface CouchQueryEnumerator ()
- (id) initWithDatabase: (CouchDatabase*)db result: (NSDictionary*)result;
@end


@interface CouchQueryRow ()
- (id) initWithDatabase: (CouchDatabase*)db result: (id)result;
@end


@interface CouchQuery ()
@property (readwrite,retain) NSError *error;
@end


@implementation CouchQuery


- (id) initWithQuery: (CouchQuery*)query {
    self = [super initWithParent: query.parent relativePath: query.relativePath];
    if (self) {
        _limit = query.limit;
        _skip = query.skip;
        self.startKey = query.startKey;
        self.endKey = query.endKey;
        _descending = query.descending;
        _prefetch = query.prefetch;
        self.keys = query.keys;
        self.mapOnly = query.mapOnly;
        _groupLevel = query.groupLevel;
        self.startKeyDocID = query.startKeyDocID;
        self.endKeyDocID = query.endKeyDocID;
        _includeDeleted = query.includeDeleted;
        _stale = query.stale;
    }
    return self;
}


- (void) dealloc
{
    [_startKey release];
    [_endKey release];
    [_startKeyDocID release];
    [_endKeyDocID release];
    [_keys release];
    [_error release];
    [super dealloc];
}


@synthesize limit=_limit, skip=_skip, descending=_descending, startKey=_startKey, endKey=_endKey,
            prefetch=_prefetch, keys=_keys, mapOnly=_mapOnly, groupLevel=_groupLevel, startKeyDocID=_startKeyDocID,
            endKeyDocID=_endKeyDocID, stale=_stale, sequences=_sequences,
            includeDeleted=_includeDeleted, error=_error;


- (CouchDesignDocument*) designDocument {
    // A CouchQuery could be a direct child of a CouchDatabase if it's _all_docs or _temp_view.
    id parent = self.parent;
    if (![parent isKindOfClass: [CouchDesignDocument class]])
        parent = nil;
    return parent;
}


- (NSDictionary*) jsonToPost {
    if (_keys)
        return [NSDictionary dictionaryWithObject: _keys forKey: @"keys"];
    else
        return nil;
}


- (NSMutableDictionary*) requestParams {
    static NSString* const kStaleNames[] = {nil, @"ok", @"update_after"}; // maps CouchStaleness
    
    NSMutableDictionary* params = [NSMutableDictionary dictionary];
    if (_limit)
        [params setObject: [NSNumber numberWithUnsignedLong: _limit] forKey: @"?limit"];
    if (_skip)
        [params setObject: [NSNumber numberWithUnsignedLong: _skip] forKey: @"?skip"];
    if (_startKey)
        [params setObject: [RESTBody stringWithJSONObject: _startKey] forKey: @"?startkey"];
    if (_endKey)
        [params setObject: [RESTBody stringWithJSONObject: _endKey] forKey: @"?endkey"];
    if (_startKeyDocID)
        [params setObject: _startKeyDocID forKey: @"?startkey_docid"];
    if (_endKeyDocID)
        [params setObject: _startKeyDocID forKey: @"?endkey_docid"];
    if (_stale != kCouchStaleNever)
        [params setObject: kStaleNames[_stale] forKey: @"?stale"];
    if (_descending)
        [params setObject: @"true" forKey: @"?descending"];
    if (_prefetch)
        [params setObject: @"true" forKey: @"?include_docs"];
    if (_sequences)
        [params setObject: @"true" forKey: @"?local_seq"];
    if (_mapOnly)
        [params setObject:@"false" forKey:@"?reduce"];
    if (_groupLevel > 0)
        [params setObject: [NSNumber numberWithUnsignedLong: _groupLevel] forKey: @"?group_level"];
    if (_includeDeleted)
        [params setObject: @"true" forKey: @"?include_deleted"];
    [params setObject: @"true" forKey: @"?update_seq"];
    return params;
}


- (RESTOperation*) start {
    NSDictionary* params = self.requestParams;
    NSDictionary* json = self.jsonToPost;
    if (json)
        return [self POSTJSON: json parameters: params];
    else
        return [self sendHTTP: @"GET" parameters: params];
}


- (CouchQueryEnumerator*) rows {
    [self cacheResponse: nil];
    return [self rowsIfChanged];
}


- (CouchQueryEnumerator*) rowsIfChanged {
    return [[self start] resultObject];
}


- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error {
    self.error = [super operation: op willCompleteWithError: error];
    if (_error)
        Warn(@"%@ failed with %@", self, _error);

    if (!_error && op.httpStatus == 200) {
        NSDictionary* result = $castIf(NSDictionary, op.responseBody.fromJSON);
        NSArray* rows = $castIf(NSArray, [result objectForKey: @"rows"]);
        if (rows) {
            [self cacheResponse: op];
            op.resultObject = [[[CouchQueryEnumerator alloc] initWithDatabase: self.database
                                                                       result: result] autorelease];
        } else {
            Warn(@"Couldn't parse rows from CouchDB view response");
            self.error = [RESTOperation errorWithHTTPStatus: 502 
                                               message: @"Couldn't parse rows from CouchDB view response" 
                                                   URL: self.URL];
        }
    }
    return _error;
}


- (CouchLiveQuery*) asLiveQuery {
    return [[[CouchLiveQuery alloc] initWithQuery: self] autorelease];
}


#pragma mark - Overrides

- (NSURL *)URL {
    NSArray *relativePathComponents = [self.relativePath pathComponents];
    NSString *prefix = relativePathComponents[0];
    
    // Init buffer with prefix and unescaped '/'
    NSMutableString *escapedCompsBuffer;
    escapedCompsBuffer = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"%@/", prefix]];
    
    // Go over rest of components, accumulating after escaping them
    for (int i = 1; i<[relativePathComponents count]; i++) {
        NSString *comp = relativePathComponents[i];
        comp = EscapeRelativePath(comp);
        [escapedCompsBuffer appendString:comp];
    }
    
    // Add a forward slash, if it's missing, to the parent URL
    NSURL *parentURL = [self.parent.URL URLByAppendingPathComponent:@""];
    NSURL *URL = [NSURL URLWithString:escapedCompsBuffer relativeToURL:parentURL];
    
    return URL;
}


@end




@implementation CouchFunctionQuery


- (id) initWithDatabase: (CouchDatabase*)db
                    map: (NSString*)map
                 reduce: (NSString*)reduce
               language: (NSString*)language
{
    NSParameterAssert(map);
    self = [super initWithParent: db relativePath: @"_temp_view"];
    if (self != nil) {
        _viewDefinition = [[NSDictionary alloc] initWithObjectsAndKeys:
                               (language ?: kCouchLanguageJavaScript), @"language",
                               map, @"map",
                               reduce, @"reduce",  // may be nil
                               nil];
    }
    return self;
}


- (void) dealloc
{
    [_viewDefinition release];
    [super dealloc];
}


- (NSDictionary*) jsonToPost {
    return _viewDefinition;
}


@end



@implementation CouchLiveQuery

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [_op release];
    [_rows release];
    [super dealloc];
}


- (CouchQueryEnumerator*) rows {
    if (!_observing)
        [self start];
    // Have to return a copy because the enumeration has to start at item #0 every time
    return [[_rows copy] autorelease];
}


- (void) setRows:(CouchQueryEnumerator *)rows {
    [_rows autorelease];
    _rows = [rows retain];
}


- (RESTOperation*) start {
    if (!_op) {
        if (!_observing) {
            _observing = YES;
            self.database.tracksChanges = YES;
            [[NSNotificationCenter defaultCenter] addObserver: self 
                                                     selector: @selector(databaseChanged)
                                                         name: kCouchDatabaseChangeNotification 
                                                       object: self.database];
        }
        COUCHLOG(@"CouchLiveQuery: Starting...");
        _op = [[super start] retain];
        [_op start];
    }
    return _op;
}


- (BOOL) wait {
    return self.rows != nil || [_op wait];
}


- (void) databaseChanged {
    [self start];
}


- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error {
    error = [super operation: op willCompleteWithError: error];

    if (op == _op) {
        COUCHLOG(@"CouchLiveQuery: ...Finished (status=%i)", op.httpStatus);
        [_op release];
        _op = nil;
        CouchQueryEnumerator* rows = op.resultObject;
        if (rows && ![rows isEqual: _rows]) {
            COUCHLOG(@"CouchLiveQuery: ...Rows changed! (now %lu)", (unsigned long)rows.count);
            self.rows = rows;   // Triggers KVO notification
            if (!self.sequences)
                self.prefetch = NO;   // (prefetch disables conditional GET shortcut on next fetch)
        
            // If this query isn't up-to-date (race condition where the db updated again after sending
            // the response), start another fetch.
            if (rows.sequenceNumber > 0 && rows.sequenceNumber < self.database.lastSequenceNumber)
                [self start];
        }
    }
    
    return error;
}


@end




@implementation CouchQueryEnumerator


@synthesize totalCount=_totalCount, sequenceNumber=_sequenceNumber;


- (id) initWithDatabase: (CouchDatabase*)database
                   rows: (NSArray*)rows
             totalCount: (NSUInteger)totalCount
         sequenceNumber: (NSUInteger)sequenceNumber
{
    NSParameterAssert(database);
    self = [super init];
    if (self ) {
        if (!rows) {
            [self release];
            return nil;
        }
        _database = database;
        _rows = [rows retain];
        _totalCount = totalCount;
        _sequenceNumber = sequenceNumber;
    }
    return self;
}

- (id) initWithDatabase: (CouchDatabase*)db result: (NSDictionary*)result {
    return [self initWithDatabase: db
                             rows: $castIf(NSArray, [result objectForKey: @"rows"])
                       totalCount: [[result objectForKey: @"total_rows"] intValue]
                   sequenceNumber: [[result objectForKey: @"update_seq"] intValue]];
}

- (id) copyWithZone: (NSZone*)zone {
    return [[[self class] alloc] initWithDatabase: _database
                                             rows: _rows
                                       totalCount: _totalCount
                                   sequenceNumber: _sequenceNumber];
}


- (void) dealloc
{
    [_rows release];
    [super dealloc];
}


- (BOOL) isEqual:(id)object {
    if (object == self)
        return YES;
    if (![object isKindOfClass: [CouchQueryEnumerator class]])
        return NO;
    CouchQueryEnumerator* otherEnum = object;
    return [otherEnum->_rows isEqual: _rows];
}


- (NSUInteger) count {
    return _rows.count;
}


- (CouchQueryRow*) rowAtIndex: (NSUInteger)index {
    return [[[CouchQueryRow alloc] initWithDatabase: _database
                                             result: [_rows objectAtIndex:index]]
            autorelease];
}


- (CouchQueryRow*) nextRow {
    if (_nextRow >= _rows.count)
        return nil;
    return [self rowAtIndex:_nextRow++];
}


- (id) nextObject {
    return [self nextRow];
}


@end




@implementation CouchQueryRow


- (id) initWithDatabase: (CouchDatabase*)database result: (id)result {
    self = [super init];
    if (self) {
        if (![result isKindOfClass: [NSDictionary class]]) {
            Warn(@"Unexpected row value in view results: %@", result);
            [self release];
            return nil;
        }
        _database = database;
        _result = [result retain];
    }
    return self;
}


- (void)dealloc {
    [_result release];
    [super dealloc];
}


- (id) key                              {return [_result objectForKey: @"key"];}
- (id) value                            {return [_result objectForKey: @"value"];}
- (NSString*) sourceDocumentID          {return [_result objectForKey: @"id"];}
- (NSDictionary*) documentProperties    {return [_result objectForKey: @"doc"];}

- (NSString*) documentID {
    NSString* docID = [[_result objectForKey: @"doc"] objectForKey: @"_id"];
    if (!docID)
        docID = [_result objectForKey: @"id"];
    return docID;
}

- (NSString*) documentRevision {
    // Get the revision id from either the embedded document contents,
    // or the '_rev' or 'rev' value key:
    NSString* rev = [[_result objectForKey: @"doc"] objectForKey: @"_rev"];
    if (!rev) {
        id value = self.value;
        if ([value isKindOfClass: [NSDictionary class]]) {      // $castIf would log a warning
            rev = [value objectForKey: @"_rev"];
            if (!rev)
                rev = [value objectForKey: @"rev"];
        }
    }
    
    if (![rev isKindOfClass: [NSString class]])                 // $castIf would log a warning
        rev = nil;
    return rev;
}


- (id) keyAtIndex: (NSUInteger)index {
    id key = [_result objectForKey: @"key"];
    if ([key isKindOfClass:[NSArray class]])
        return (index < [key count]) ? [key objectAtIndex: index] : nil;
    else
        return (index == 0) ? key : nil;
}

- (id) key0                         {return [self keyAtIndex: 0];}
- (id) key1                         {return [self keyAtIndex: 1];}
- (id) key2                         {return [self keyAtIndex: 2];}
- (id) key3                         {return [self keyAtIndex: 3];}


- (CouchDocument*) document {
    NSString* docID = self.documentID;
    if (!docID)
        return nil;
    CouchDocument* doc = [_database documentWithID: docID];
    [doc loadCurrentRevisionFrom: self];
    return doc;
}


- (UInt64) localSequence {
    id seq = [self.documentProperties objectForKey: @"_local_seq"];
    return $castIf(NSNumber, seq).unsignedLongLongValue;
}


- (NSString*) description {
    return [NSString stringWithFormat: @"%@[key=%@; value=%@; id=%@]",
            [self class],
            [RESTBody stringWithJSONObject: self.key],
            [RESTBody stringWithJSONObject: self.value],
            self.documentID];
}


@end
