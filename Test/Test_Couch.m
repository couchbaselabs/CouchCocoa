//
//  Test_Couch.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/12/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CouchInternal.h"
#import "CouchDesignDocument.h"
#import "RESTInternal.h"
#import "CouchTestCase.h"


@interface Test_Couch : CouchTestCase
@end


@implementation Test_Couch


- (CouchDocument*) createDocumentWithProperties: (NSDictionary*)properties {
    CouchDocument* doc = [_db untitledDocument];
    STAssertNotNil(doc, @"Couldn't create doc");
    STAssertNil(doc.currentRevisionID, nil);
    STAssertNil(doc.currentRevision, nil);
    STAssertNil(doc.documentID, nil);
    
    AssertWait([doc putProperties: properties]);  // save it!
    
    STAssertNotNil(doc.documentID, nil);
    STAssertNotNil(doc.currentRevisionID, nil);
    STAssertEqualObjects(doc.userProperties, properties, @"");
    STAssertEquals([_db documentWithID: doc.documentID], doc, @"Saved document wasn't cached");
    NSLog(@"Created %p = %@", doc, doc);
    return doc;
}


- (void) createDocuments: (unsigned)n {
    for (int i=0; i<n; i++) {
        NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"testDatabase", @"testName",
                                    [NSNumber numberWithInt: i], @"sequence",
                                    nil];
        [self createDocumentWithProperties: properties];
    }
}


#pragma mark - SERVER & DOCUMENTS:


- (void) test01_Server {
    static const NSUInteger kUUIDCount = 5;
    NSError* error;
    NSString* version = [_server getVersion: &error];
    STAssertNotNil(version, @"Failed to get server version");
    NSLog(@"Server is version %@", version);
    
    NSArray* uuids = [_server generateUUIDs: kUUIDCount];
    STAssertNotNil(uuids, @"Failed to get UUIDs");
    STAssertEquals(uuids.count, kUUIDCount, @"Wrong number of UUIDs");
    NSLog(@"Have some UUIDs: %@", [uuids componentsJoinedByString: @", "]);
    
    for (CouchDatabase *db in [_server getDatabases]) {
        NSLog(@"Database '%@': %ld documents", db.relativePath, (long)[db getDocumentCount]);
    }
    
    // Test the +databaseWithURL: factory method:
    CouchDatabase* db2 = [CouchDatabase databaseWithURL: _db.URL];
    STAssertNotNil(db2, @"+databaseWithURL failed");
    STAssertEqualObjects(db2.URL, _db.URL, nil);
    STAssertEqualObjects(db2.parent.URL, _server.URL, nil);
}


- (void) test02_CreateDocument {
    NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"testCreateDocument", @"testName",
                                [NSNumber numberWithInt:1337], @"tag",
                                nil];
    CouchDocument* doc = [self createDocumentWithProperties: properties];
    
    NSString* docID = doc.documentID;
    STAssertTrue(docID.length > 10, @"Invalid doc ID: '%@'", docID);
    NSString* currentRevisionID = doc.currentRevisionID;
    STAssertTrue(currentRevisionID.length > 10, @"Invalid doc revision: '%@'", currentRevisionID);

    STAssertEqualObjects(doc.userProperties, properties, @"Couldn't get doc properties");

    RESTOperation* op = AssertWait([doc GET]);
    STAssertEquals(op.httpStatus, 200, @"GET failed");

    STAssertEqualObjects(doc.userProperties, properties, @"Couldn't get doc properties after GET");
}


- (void) test02_CreateRevisions {
    NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"testCreateRevisions", @"testName",
                                [NSNumber numberWithInt:1337], @"tag",
                                nil];
    CouchDocument* doc = [self createDocumentWithProperties: properties];
    CouchRevision* rev1 = doc.currentRevision;
    STAssertTrue([rev1.revisionID hasPrefix: @"1-"], nil);
    
    NSMutableDictionary* properties2 = [[properties mutableCopy] autorelease];
    [properties2 setObject: [NSNumber numberWithInt: 4567] forKey: @"tag"];
    RESTOperation* op = [rev1 putProperties: properties2];
    AssertWait(op);
    
    STAssertTrue([doc.currentRevisionID hasPrefix: @"2-"],
                 @"Document revision ID is still %@", doc.currentRevisionID);
    
    CouchRevision* rev2 = op.resultObject;
    STAssertTrue([rev2 isKindOfClass: [CouchRevision class]], nil);
    STAssertEqualObjects(rev2.revisionID, doc.currentRevisionID, nil);
    STAssertTrue(rev2.propertiesAreLoaded, nil);
    STAssertEqualObjects(rev2.userProperties, properties2, nil);
    STAssertEquals(rev2.document, doc, nil);
}


- (void) test03_SaveMultipleDocuments {
    NSMutableArray* docs = [NSMutableArray array];
    for (int i=0; i<5; i++) {
        NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"testSaveMultipleDocuments", @"testName",
                                    [NSNumber numberWithInt: i], @"sequence",
                                    nil];
        CouchDocument* doc = [self createDocumentWithProperties: properties];
        [docs addObject: doc];
    }
    
    NSMutableArray* revisions = [NSMutableArray array];
    NSMutableArray* revisionProperties = [NSMutableArray array];
    
    for (CouchDocument* doc in docs) {
        CouchRevision* revision = doc.currentRevision;
        STAssertTrue([revision.revisionID hasPrefix: @"1-"],
                     @"Expected 1st revision: %@ in %@", doc.currentRevisionID, doc);
        NSMutableDictionary* properties = revision.properties.mutableCopy;
        [properties setObject: @"updated!" forKey: @"misc"];
        [revisions addObject: revision];
        [revisionProperties addObject: properties];
        [properties release];
    }
    
    AssertWait([_db putChanges: revisionProperties toRevisions: revisions]);
    
    for (CouchDocument* doc in docs) {
        STAssertTrue([doc.currentRevisionID hasPrefix: @"2-"],
                     @"Expected 2nd revision: %@ in %@", doc.currentRevisionID, doc);
        STAssertEqualObjects([doc.currentRevision.properties objectForKey: @"misc"],
                             @"updated!", nil);
    }
}


- (void) test03_DeleteMultipleDocuments {
    NSMutableArray* docs = [NSMutableArray array];
    for (int i=0; i<5; i++) {
        NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"testDeleteMultipleDocuments", @"testName",
                                    [NSNumber numberWithInt: i], @"sequence",
                                    nil];
        CouchDocument* doc = [self createDocumentWithProperties: properties];
        [docs addObject: doc];
    }
    
    AssertWait([_db deleteDocuments: docs]);
    
    for (CouchDocument* doc in docs) {
        STAssertTrue(doc.isDeleted, nil);
    }
    
    STAssertEquals([_db getDocumentCount], (NSInteger)0, nil);
}


- (void) test04_DeleteDocument {
    NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"testDeleteDocument", @"testName",
                                nil];
    CouchDocument* doc = [self createDocumentWithProperties: properties];
    STAssertFalse(doc.isDeleted, nil);
    AssertWait([doc DELETE]);
    STAssertTrue(doc.isDeleted, nil);
}


- (void) test05_AllDocuments {
    static const NSUInteger kNDocs = 5;
    [self createDocuments: kNDocs];

    // clear the cache so all documents/revisions will be re-fetched:
    [_db clearDocumentCache];
    
    NSLog(@"----- all documents -----");
    CouchQuery* query = [_db getAllDocuments];
    //query.prefetch = YES;
    NSLog(@"Getting all documents: %@", query);
    
    CouchQueryEnumerator* rows = query.rows;
    STAssertEquals(rows.count, kNDocs, nil);
    STAssertEquals(rows.totalCount, kNDocs, nil);
    NSUInteger n = 0;
    for (CouchQueryRow* row in rows) {
        NSLog(@"    --> %@", row);
        CouchDocument* doc = row.document;
        STAssertNotNil(doc, @"Couldn't get doc from query");
        STAssertTrue(doc.currentRevision.propertiesAreLoaded, @"QueryRow should have preloaded revision contents");
        NSLog(@"        Properties = %@", doc.properties);
        STAssertNotNil(doc.properties, @"Couldn't get doc properties");
        STAssertEqualObjects([doc propertyForKey: @"testName"], @"testDatabase", @"Wrong doc contents");
        n++;
    }
    STAssertEquals(n, kNDocs, @"Query returned wrong document count");
}


- (void) test06_RowsIfChanged {
    static const NSUInteger kNDocs = 5;
    [self createDocuments: kNDocs];
    // clear the cache so all documents/revisions will be re-fetched:
    [_db clearDocumentCache];
    
    CouchQuery* query = [_db getAllDocuments];
    query.prefetch = NO;    // Prefetching prevents view caching, so turn it off
    CouchQueryEnumerator* rows = query.rows;
    STAssertEquals(rows.count, kNDocs, nil);
    STAssertEquals(rows.totalCount, kNDocs, nil);
    
    // Make sure the query is cached (view eTag hasn't changed):
    STAssertNil(query.rowsIfChanged, @"View eTag must have changed?");
    
    // Get the rows again to make sure caching isn't messing up:
    rows = query.rows;
    STAssertEquals(rows.count, kNDocs, nil);
    STAssertEquals(rows.totalCount, kNDocs, nil);
}

#pragma mark - HISTORY

- (void)test07_History {
    NSMutableDictionary* properties = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                @"test06_History", @"testName",
                                [NSNumber numberWithInt:1], @"tag",
                                nil];
    CouchDocument* doc = [self createDocumentWithProperties: properties];
    NSString* rev1ID = [[doc.currentRevisionID copy] autorelease];
    NSLog(@"1st revision: %@", rev1ID);
    STAssertTrue([rev1ID hasPrefix: @"1-"], @"1st revision looks wrong: '%@'", rev1ID);
    STAssertEqualObjects(doc.userProperties, properties, nil);
    properties = [doc.properties.mutableCopy autorelease];
    [properties setObject: [NSNumber numberWithInt: 2] forKey: @"tag"];
    STAssertFalse([properties isEqual: doc.properties], nil);
    AssertWait([doc putProperties: properties]);
    NSString* rev2ID = doc.currentRevisionID;
    NSLog(@"2nd revision: %@", rev2ID);
    STAssertTrue([rev2ID hasPrefix: @"2-"], @"2nd revision looks wrong: '%@'", rev2ID);
    
    NSArray* revisions = [doc getRevisionHistory];
    NSLog(@"Revisions = %@", revisions);
    STAssertEquals(revisions.count, (NSUInteger)2, nil);
    
    CouchRevision* rev1 = [revisions objectAtIndex: 0];
    STAssertEqualObjects(rev1.revisionID, rev1ID, nil);
    NSDictionary* gotProperties = rev1.properties;
    STAssertEqualObjects([gotProperties objectForKey: @"tag"], [NSNumber numberWithInt: 1], nil);
    
    CouchRevision* rev2 = [revisions objectAtIndex: 1];
    STAssertEqualObjects(rev2.revisionID, rev2ID, nil);
    STAssertEquals(rev2, doc.currentRevision, @"rev2 = %@; current = %@", rev2, doc.currentRevision);
    gotProperties = rev2.properties;
    STAssertEqualObjects([gotProperties objectForKey: @"tag"], [NSNumber numberWithInt: 2], nil);
    
    STAssertEqualObjects(doc.getConflictingRevisions,
                         [NSArray arrayWithObject: rev2], nil);
}


#pragma mark - ATTACHMENTS


- (void) test08_Attachments {
    NSDictionary* properties = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"testAttachments", @"testName",
                                nil];
    CouchDocument* doc = [self createDocumentWithProperties: properties];
    CouchRevision* rev = doc.currentRevision;
    
    STAssertEquals(rev.attachmentNames.count, (NSUInteger)0, nil);
    STAssertNil([rev attachmentNamed: @"index.html"], nil);
    
    CouchAttachment* attach = [rev createAttachmentWithName: @"index.html"
                                                       type: @"text/plain; charset=utf-8"];
    STAssertNotNil(attach, nil);
    STAssertEquals(attach.parent, rev, nil);
    STAssertEquals(attach.revision, rev, nil);
    STAssertEquals(attach.document, doc, nil);
    STAssertEqualObjects(attach.relativePath, @"index.html", nil);
    STAssertEqualObjects(attach.name, attach.relativePath, nil);
    
    NSData* body = [@"This is a test attachment!" dataUsingEncoding: NSUTF8StringEncoding];
    AssertWait([attach PUT: body]);
    
    CouchRevision* rev2 = doc.currentRevision;
    STAssertTrue([rev2.revisionID hasPrefix: @"2-"], nil);
    NSLog(@"Now attachments = %@", rev2.attachmentNames);
    STAssertEqualObjects(rev2.attachmentNames, [NSArray arrayWithObject: @"index.html"], nil);

    attach = [rev2 attachmentNamed: @"index.html"];
    RESTOperation* op = [attach GET];
    AssertWait(op);
    STAssertEqualObjects(op.responseBody.contentType, @"text/plain; charset=utf-8", nil);
    STAssertEqualObjects(op.responseBody.content, body, nil);
    
    AssertWait([doc GET]);

    AssertWait([attach DELETE]);
}


#pragma mark - CHANGE TRACKING


- (void) test09_ChangeTracking {
    CouchDatabase* userDB = [_server databaseNamed: @"_users"];
    __block int changeCount = 0;
    [userDB onChange: ^(CouchDocument* doc){ ++changeCount; }];
    userDB.lastSequenceNumber = 0;
    userDB.tracksChanges = YES;

    NSDate* stopAt = [NSDate dateWithTimeIntervalSinceNow: 1.0];
    while (changeCount < 1 && [stopAt timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
    STAssertTrue(changeCount > 0, nil);
}


- (void) test10_ChangeTrackingNoEchoes {
    __block int changeCount = 0;
    [_db onChange: ^(CouchDocument* doc){ ++changeCount; }];
    _db.tracksChanges = YES;
    
    [self createDocuments: 2];
    
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
    // We expect that the changes reported by the server won't be notified, because those revisions
    // are already cached in memory.
    STAssertEquals(changeCount, 0, nil);
    
    STAssertEquals(_db.lastSequenceNumber, (NSUInteger)2, nil);
}


- (void) test11_ChangeTrackingNoEchoesAfterTheFact {
    __block int changeCount = 0;
    [_db onChange: ^(CouchDocument* doc){ ++changeCount; }];
    
    [self createDocuments: 5];

    // This time don't turn on change tracking till after the docs are created.
    _db.tracksChanges = YES;

    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 1.0]];
    // We expect that the changes reported by the server won't be notified, because those revisions
    // are already cached in memory.
    STAssertEquals(changeCount, 0, nil);
    
    STAssertEquals(_db.lastSequenceNumber, (NSUInteger)5, nil);
}


#pragma mark - VIEWS:


- (void) test12_CreateView {
    CouchDesignDocument* design = [_db designDocumentWithName: @"mydesign"];
    STAssertNotNil(design, nil);
    STAssertFalse(design.changed, nil);
    STAssertEqualObjects(design.viewNames, [NSArray array], nil);
    [design defineViewNamed: @"vu" map: @"function(doc){emit(doc.name,null);};"
                     reduce: @"_count"];
    STAssertEqualObjects(design.viewNames, [NSArray arrayWithObject: @"vu"], nil);
    STAssertEqualObjects([design mapFunctionOfViewNamed: @"vu"],
                         @"function(doc){emit(doc.name,null);};", nil);
    STAssertEqualObjects([design reduceFunctionOfViewNamed: @"vu"], @"_count", nil);
    STAssertEqualObjects(design.language, kCouchLanguageJavaScript, nil);

    STAssertTrue(design.changed, nil);
    AssertWait([design saveChanges]);
    STAssertFalse(design.changed, nil);

    [design defineViewNamed: @"vu" map: @"function(doc){emit(doc.name,null);};"
                     reduce: @"_count"];
    STAssertFalse(design.changed, nil);
    STAssertNil([design saveChanges], nil);

    [design defineViewNamed: @"vu" map: nil];
    STAssertEqualObjects(design.viewNames, [NSArray array], nil);
    
    STAssertTrue(design.changed, nil);
    AssertWait([design saveChanges]);
    STAssertFalse(design.changed, nil);
}


- (void) test13_RunView {
    static const NSUInteger kNDocs = 50;
    [self createDocuments: kNDocs];
    
    CouchDesignDocument* design = [_db designDocumentWithName: @"mydesign"];
    [design defineViewNamed: @"vu" map: @"function(doc){emit(doc.sequence,null);};"];
    AssertWait([design saveChanges]);
    
    CouchQuery* query = [design queryViewNamed: @"vu"];
    query.startKey = [NSNumber numberWithInt: 23];
    query.endKey = [NSNumber numberWithInt: 33];
    CouchQueryEnumerator* rows = query.rows;
    STAssertNotNil(rows, nil);
    STAssertEquals(rows.count, (NSUInteger)11, nil);
    STAssertEquals(rows.totalCount, kNDocs, nil);
    
    int expectedKey = 23;
    for (CouchQueryRow* row in rows) {
        STAssertEquals([row.key intValue], expectedKey, nil);
        ++expectedKey;
    }
}


- (void) test14_RunSlowView {
    static const NSUInteger kNDocs = 50;
    [self createDocuments: kNDocs];
    
    CouchQuery* query = [_db slowQueryWithMap: @"function(doc){emit(doc.sequence,null);};"];
    query.startKey = [NSNumber numberWithInt: 23];
    query.endKey = [NSNumber numberWithInt: 33];
    CouchQueryEnumerator* rows = query.rows;
    STAssertNotNil(rows, nil);
    STAssertEquals(rows.count, (NSUInteger)11, nil);
    STAssertEquals(rows.totalCount, kNDocs, nil);
    
    int expectedKey = 23;
    for (CouchQueryRow* row in rows) {
        STAssertEquals([row.key intValue], expectedKey, nil);
        ++expectedKey;
    }
}


- (void) test15_UncacheViews {
    CouchDesignDocument* design = [_db designDocumentWithName: @"mydesign"];
    [design defineViewNamed: @"vu" map: @"function(doc){emit(doc.name,null);};"
                     reduce: @"_count"];
    AssertWait([design saveChanges]);

    // Delete the view without going through the view API:
    NSMutableDictionary* props = [design.properties mutableCopy];
    [props removeObjectForKey: @"views"];
    AssertWait([design putProperties: props]);
    
    // Verify that the view API knows it's gone:
    STAssertEqualObjects(design.viewNames, [NSArray array], nil);
}


- (void) test13_Validation {
    CouchDesignDocument* design = [_db designDocumentWithName: @"mydesign"];
    design.validation = @"function(doc,oldDoc,user){if(!doc.groovy) throw({forbidden:'uncool'});}";
    AssertWait([design saveChanges]);
    
    NSMutableDictionary* properties = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       @"right on", @"groovy",
                                       @"bar", @"foo", nil];
    CouchDocument* doc = [_db untitledDocument];
    AssertWait([doc putProperties: properties]);
    
    [properties removeObjectForKey: @"groovy"];
    doc = [_db untitledDocument];
    RESTOperation* op = [doc putProperties: properties];
    STAssertFalse([op wait], nil);
    STAssertEquals(op.error.code, (NSInteger)403, nil);
    STAssertEqualObjects(op.error.localizedDescription, @"forbidden: uncool", nil);
}


@end
