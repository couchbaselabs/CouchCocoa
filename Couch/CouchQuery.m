//
//  CouchQuery.m
//  CouchCocoa
//
//  Created by Jens Alfke on 5/30/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

// <http://wiki.apache.org/couchdb/HTTP_view_API#Querying_Options>


#import "CouchQuery.h"
#import "CouchDesignDocument.h"
#import "CouchInternal.h"

#import "JSONKit.h"


@interface CouchQueryEnumerator ()
- (id) initWithQuery: (CouchQuery*)query op: (RESTOperation*)op;
@end


@interface CouchQueryRow ()
- (id) initWithQuery: (CouchQuery*)query result: (id)result;
@end



@implementation CouchQuery


@synthesize limit=_limit, skip=_skip, descending=_descending, startKey=_startKey, endKey=_endKey,
            prefetch=_prefetch, keys=_keys, groupLevel=_groupLevel;


- (CouchDesignDocument*) designDocument {
    // The relativePath to a view URL will look like "_design/DOCNAME/_view/VIEWNAME"
    NSArray* path = [self.relativePath componentsSeparatedByString: @"/"];
    if (path.count >= 4 && [[path objectAtIndex: 0] isEqualToString: @"_design"])
        return [self.database designDocumentWithName: [path objectAtIndex: 1]];
    else
        return nil;
}


- (NSDictionary*) jsonToPost {
    if (_keys)
        return [NSDictionary dictionaryWithObject: _keys forKey: @"keys"];
    else
        return nil;
}


- (NSMutableDictionary*) requestParams {
    NSMutableDictionary* params = [NSMutableDictionary dictionary];
    if (_limit)
        [params setObject: [NSNumber numberWithUnsignedLong: _limit] forKey: @"?limit"];
    if (_skip)
        [params setObject: [NSNumber numberWithUnsignedLong: _skip] forKey: @"?skip"];
    if (_startKey)
        [params setObject: [_startKey JSONString] forKey: @"?startkey"];
    if (_endKey)
        [params setObject: [_endKey JSONString] forKey: @"?endkey"];
    if (_descending)
        [params setObject: @"true" forKey: @"?descending"];
    if (_prefetch)
        [params setObject: @"true" forKey: @"?include_docs"];
    if (_groupLevel > 0)
        [params setObject: [NSNumber numberWithUnsignedInt: _groupLevel] forKey: @"?group_level"];
    return params;
}


- (RESTOperation*) createResponse {
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
    RESTOperation* op = [self createResponse];
    if (op.isSuccessful && op.httpStatus == 304)
        return nil;  // unchanged
    NSArray* rows = $castIf(NSArray, [op.responseBody.fromJSON objectForKey: @"rows"]);    // BLOCKING
    if (!rows) {
        Warn(@"Error getting %@: %@", self, op.error);
        return nil;
    }
    [self cacheResponse: op];
    return [[[CouchQueryEnumerator alloc] initWithQuery: self op: op] autorelease];
}


@end




@implementation CouchFunctionQuery


- (id) initWithDatabase: (CouchDatabase*)db
         viewDefinition: (struct CouchViewDefinition)definition
{
    self = [super initWithParent: db relativePath: @"_temp_view"];
    if (self != nil) {
        _viewDefinition = [[NSDictionary alloc] initWithObjectsAndKeys:
                               definition.mapFunction, @"map",
                               definition.reduceFunction, @"reduce",  // may be nil
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




@implementation CouchQueryEnumerator


@synthesize totalCount=_totalCount;


- (id) initWithQuery: (CouchQuery*)query op: (RESTOperation*)op {
    self = [super init];
    if (self) {
        _query = [query retain];
        _rows = [$castIf(NSArray, [op.responseBody.fromJSON objectForKey: @"rows"]) retain];    // BLOCKING
        if (!_rows) {
            [self release];
            return nil;
        }
        _totalCount = [[op.responseBody.fromJSON objectForKey: @"total_rows"] intValue];
    }
    return self;
}


- (void) dealloc
{
    [_query release];
    [_rows release];
    [super dealloc];
}


- (NSUInteger) count {
    return _rows.count;
}


- (CouchQueryRow*) rowAtIndex: (NSUInteger)index {
    return [[[CouchQueryRow alloc] initWithQuery: _query
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


- (id) initWithQuery: (CouchQuery*)query result: (id)result {
    self = [super init];
    if (self) {
        if (![result isKindOfClass: [NSDictionary class]]) {
            Warn(@"Unexpected row value in view results: %@", result);
            [self release];
            return nil;
        }
        _query = [query retain];
        _result = [result retain];
    }
    return self;
}


@synthesize query=_query;

- (id) key                          {return [_result objectForKey: @"key"];}
- (id) value                        {return [_result objectForKey: @"value"];}
- (NSString*) documentID            {return [_result objectForKey: @"id"];}
- (NSDictionary*) documentContents  {return [_result objectForKey: @"doc"];}


- (CouchDocument*) document {
    NSString* docID = [_result objectForKey: @"id"];
    if (!docID)
        return nil;
    CouchDocument* doc = [_query.database documentWithID: docID];
    [doc loadCurrentRevisionFrom: self.documentContents];
    return doc;
}


- (NSString*) description {
    return [NSString stringWithFormat: @"%@[key=%@; value=%@; id=%@]",
            [self class],
            [self.key JSONString], [self.value JSONString], self.documentID];
}


@end
