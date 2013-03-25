//
//  CouchDatabase.m
//  CouchCocoa
//
//  Created by Jens Alfke on 5/26/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CouchDatabase.h"
#import "RESTCache.h"
#import "CouchChangeTracker.h"
#import "CouchInternal.h"


NSString* const kCouchDatabaseChangeNotification = @"CouchDatabaseChange";


/** Number of CouchDocument objects to cache in memory */
static const NSUInteger kDocRetainLimit = 50;


@interface CouchDatabase () <CouchChangeTrackerClient>
- (void) processDeferredChanges;
@end


@implementation CouchDatabase


+ (CouchDatabase*) databaseNamed: (NSString*)databaseName
                 onServerWithURL: (NSURL*)serverURL
{
    CouchServer* server = [[[CouchServer alloc] initWithURL: serverURL] autorelease];
    return [server databaseNamed: databaseName];
}


+ (CouchDatabase*) databaseWithURL: (NSURL*)databaseURL {
    return [self databaseNamed: [databaseURL lastPathComponent]
               onServerWithURL: [databaseURL URLByDeletingLastPathComponent]];
}


- (void) close {
    self.tracksChanges = NO;
    _lastSequenceNumber = 0;
    _lastSequenceNumberKnown = NO;
    [_busyDocuments release];
    _busyDocuments = nil;
    [_deferredChanges release];
    _deferredChanges = nil;
    [_docCache release];
    _docCache = nil;
}


- (void)dealloc {
    [self close];
    [_onChangeBlock release];
    [_modelFactory release];
    [super dealloc];
}


- (CouchServer*) server {
    return (CouchServer*)[self parent];
}


- (CouchDatabase*) database {
    return self;
}


- (RESTOperation*) create {
    return [[self PUT: nil parameters: nil] start];
}


- (void)setDocumentPathMap: (CouchDocumentPathMap)documentPathMap
{
    [_documentPathMap release];
    _documentPathMap = [documentPathMap copy];
    [_docCache forgetAllResources];
}


- (CouchDocumentPathMap) documentPathMap
{
    return _documentPathMap;
}


- (BOOL) ensureCreated: (NSError**)outError {
    RESTOperation* op = [self create];
    if (![op wait] && op.httpStatus != 412) {
        if (outError) *outError = op.error;
        return NO;
    }
    return YES;
}


- (RESTOperation*) compact {
    // http://wiki.apache.org/couchdb/Compaction
    NSDictionary* params = [NSDictionary dictionaryWithObject: @"application/json"
                                                       forKey: @"Content-Type"];
    return [[[self childWithPath: @"_compact"] POST: nil parameters: params] start];
}


- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error {
    error = [super operation: op willCompleteWithError: error];
    if (op.isDELETE && !error) {
        // Database deleted!
        [self close];
    }
    return error;
}


#pragma mark - DOCUMENTS:


- (NSInteger) getDocumentCount {
    id count = [[self GET].responseBody.fromJSON objectForKey: @"doc_count"];  // synchronous
    return [count isKindOfClass: [NSNumber class]] ? [count intValue] : -1;
}


- (CouchDocument*) documentWithID: (NSString*)docID {
    NSString *relativePath = _documentPathMap ? _documentPathMap(docID) : docID;
    
    CouchDocument* doc = (CouchDocument*) [_docCache resourceWithRelativePath: relativePath];
    if (!doc) {
        if (docID.length == 0)
            return nil;
        if ([docID hasPrefix: @"_design/"])     // Create a design doc when appropriate
            doc = [[CouchDesignDocument alloc] initWithParent: self relativePath: docID];
        else
            doc = [[CouchDocument alloc] initWithParent: self
                                           relativePath: relativePath
                                             documentID: docID];
        if (!doc)
            return nil;
        if (!_docCache)
            _docCache = [[RESTCache alloc] initWithRetainLimit: kDocRetainLimit];
        [_docCache addResource: doc];
        [doc autorelease];
    }
    return doc;
}

/** Same as -documentWithID:. Enables "[]" access in Xcode 4.4+ */
- (id)objectForKeyedSubscript:(NSString*)key {
    return [self documentWithID: key];
}


- (CouchDesignDocument*) designDocumentWithName: (NSString*)name {
    return (CouchDesignDocument*)[self documentWithID: [@"_design/" stringByAppendingString: name]];
}
            
            
- (CouchDocument*) untitledDocument {
    // Don't create genuinely untitled documents -- it complicates the doc-ID cache and makes it
    // too difficult to enforce having only one CouchDocument instance per document ID:
    // <https://github.com/couchbaselabs/TouchDB-iOS/issues/140>
    return [self documentWithID: [self.server generateDocumentID]];
}


- (void) documentAssignedID: (CouchDocument*)document {
    if (!_docCache)
        _docCache = [[RESTCache alloc] initWithRetainLimit: kDocRetainLimit];
    [_docCache addResource: document];
}


- (void) clearDocumentCache {
    [_docCache forgetAllResources];
}

- (void) unretainDocumentCache {
    [_docCache unretainResources];
}


#pragma mark -
#pragma mark BATCH CHANGES


- (RESTOperation*) putChanges: (NSArray*)properties {
    return [self putChanges: properties toRevisions: nil];
}

- (RESTOperation*) putChanges: (NSArray*)properties toRevisions: (NSArray*)revisions {
    // http://wiki.apache.org/couchdb/HTTP_Bulk_Document_API
    NSUInteger nChanges = properties.count;
    NSAssert(revisions==nil || revisions.count == nChanges, @"Mismatched array counts");
    NSMutableArray* entries = [NSMutableArray arrayWithCapacity: nChanges];
    for (NSUInteger i=0; i<nChanges; i++) {
        id props = [properties objectAtIndex: i];
        NSMutableDictionary* contents;
        if ([props isEqual: [NSNull null]]) {
            NSAssert(revisions, @"Can't pass null properties without specifying a revision");
            contents = [NSMutableDictionary dictionaryWithObject: (id)kCFBooleanTrue
                                                          forKey: @"_deleted"];
        } else {
            NSAssert([props isKindOfClass:[NSDictionary class]], @"invalid property dict");
            contents = [[props mutableCopy] autorelease];
        }
        if (revisions) {
            // Elements of 'revisions' may be CouchRevisions or CouchDocuments.
            id revOrDoc = [revisions objectAtIndex: i];
            NSString* docID = [revOrDoc documentID];
            if (docID) {
                [contents setObject: docID forKey: @"_id"];
                if ([revOrDoc isKindOfClass: [CouchRevision class]])
                    [contents setObject: [revOrDoc revisionID] forKey: @"_rev"];
            }
        }
        [entries addObject: contents];
    }
    NSDictionary* body = [NSDictionary dictionaryWithObject: entries forKey: @"docs"];
    
    [self beginDocumentOperation: self];
    RESTOperation* op = [[self childWithPath: @"_bulk_docs"] POSTJSON: body parameters: nil];
    [op onCompletion: ^{
        if (op.isSuccessful) {
            NSArray* responses = $castIf(NSArray, op.responseBody.fromJSON);
            op.resultObject = [NSMutableArray arrayWithCapacity: nChanges];
            int i = 0;
            for (id response in responses) {
                NSDictionary* responseDict = $castIf(NSDictionary, response);
                CouchDocument* document;
                if (revisions) {
                    id revOrDoc = [revisions objectAtIndex: i];
                    if ([revOrDoc isKindOfClass: [CouchRevision class]])
                        document = [revOrDoc document];
                    else
                        document = revOrDoc;
                } else
                    document = [self documentWithID: [responseDict objectForKey: @"id"]];
                [document bulkSaveCompleted: responseDict
                              forProperties: [entries objectAtIndex: i]];
                [op.resultObject addObject: document];
                ++i;
            }
        }
        [self endDocumentOperation: self];
    }];
    return op;
}


- (RESTOperation*) deleteRevisions: (NSArray*)revisions {
    NSArray* properties = [revisions rest_map: ^(id revision) {return [NSNull null];}];
    return [self putChanges: properties toRevisions: revisions];
}


- (RESTOperation*) deleteDocuments: (NSArray*)documents {
    NSArray* revisions = [documents rest_map: ^(id document) {return [document currentRevision];}];
    return [self deleteRevisions: revisions];
}


- (RESTOperation*) purgeDocuments: (NSArray*)documents {
    NSMutableDictionary* param = [NSMutableDictionary dictionary];
    for (id doc in documents) {
        NSString* docID;
        if ([doc isKindOfClass: [NSString class]])
            docID = doc;
        else
            docID = ((CouchDocument*)doc).documentID;
        [param setObject: [NSMutableArray arrayWithObject: @"*"] forKey: docID];
    }
    return [[self childWithPath: @"_purge"] POSTJSON: param parameters: nil];
}


- (void) beginDocumentOperation: (CouchResource*)resource {
    if (!_busyDocuments)
        _busyDocuments = [[NSCountedSet alloc] init];
    [_busyDocuments addObject: resource];
    COUCHLOG(@">>>>>> %lu docs being updated", (unsigned long)_busyDocuments.count);
}


- (void) endDocumentOperation: (CouchResource*)resource {
    NSAssert([_busyDocuments containsObject: resource], @"unbalanced endDocumentOperation call: %p %@", resource, resource);
    [_busyDocuments removeObject: resource];
    COUCHLOG(@"<<<<<< %lu docs being updated", (unsigned long)_busyDocuments.count);
    if (_busyDocuments.count == 0)
        [self processDeferredChanges];
}


#pragma mark -
#pragma mark QUERIES


- (CouchQuery*) getAllDocuments {
    CouchQuery *query = [[[CouchQuery alloc] initWithParent: self relativePath: @"_all_docs"] autorelease];
    query.prefetch = YES;
    return query;
}


- (CouchQuery*) getDocumentsWithIDs: (NSArray*)docIDs {
    CouchQuery *query = [self getAllDocuments];
    query.keys = docIDs;
    query.prefetch = YES;
    return query;
}


- (CouchQuery*) slowQueryWithMap: (NSString*)map
                          reduce: (NSString*)reduce
                        language: (NSString*)language
{
    return [[[CouchFunctionQuery alloc] initWithDatabase: self
                                                     map: map
                                                  reduce: reduce
                                                language: language] autorelease];
}

- (CouchQuery*) slowQueryWithMap: (NSString*)map {
    return [[[CouchFunctionQuery alloc] initWithDatabase: self
                                                     map: map
                                                  reduce: nil
                                                language: nil] autorelease];
}


#pragma mark -
#pragma mark REPLICATION & SYNCHRONIZATION

- (CouchReplication*) pullFromDatabaseAtURL: (NSURL*)sourceURL {
    CouchReplication* rep = [self pushToDatabaseAtURL: sourceURL];
    rep.pull = YES;
    return rep;
}

- (CouchReplication*) pushToDatabaseAtURL: (NSURL*)targetURL
{
    return [[[CouchReplication alloc] initWithDatabase: self remote: targetURL] autorelease];
}


- (NSArray*) replications {
    NSString* myPath = self.relativePath;
    return [self.server.replications rest_map: ^id(CouchPersistentReplication* repl) {
        if ([repl.sourceURLStr isEqualToString: myPath] ||
                [repl.targetURLStr isEqualToString: myPath])
            return repl;
        else
            return nil;
    }];
}


- (CouchPersistentReplication*) replicationFromDatabaseAtURL: (NSURL*)sourceURL {
    return [self.server replicationWithSource: sourceURL.absoluteString target: self.relativePath];
}

- (CouchPersistentReplication*) replicationToDatabaseAtURL: (NSURL*)targetURL {
    return [self.server replicationWithSource: self.relativePath target: targetURL.absoluteString];
}

- (CouchPersistentReplication*) createPersistentPullFromDatabaseAtURL: (NSURL*)sourceURL {

    return [CouchPersistentReplication createWithReplicatorDatabase: self.server.replicatorDatabase
                                                             source: sourceURL.absoluteString
                                                             target: self.relativePath];
}

- (CouchPersistentReplication*) createPersistentPushToDatabaseAtURL: (NSURL*)targetURL {

    return [CouchPersistentReplication createWithReplicatorDatabase: self.server.replicatorDatabase
                                                             source: self.relativePath
                                                             target: targetURL.absoluteString];
}


- (NSArray*) replicateWithURL: (NSURL*)targetURL exclusively: (BOOL)exclusively {
    NSMutableArray* repls = nil;
    if (targetURL) {
        CouchPersistentReplication* from = [self replicationFromDatabaseAtURL: targetURL];
        CouchPersistentReplication* to = [self replicationToDatabaseAtURL: targetURL];
        if (!from || !to)
            return nil;
        if (from.isNew)
            from.continuous = YES;  // New replications are continuous by default
        if (to.isNew)
            to.continuous = YES;
        repls = [NSMutableArray arrayWithObjects: from, to, nil];
    }
    if (exclusively) {
        for (CouchPersistentReplication* repl in self.replications) {
            if (!repls || [repls indexOfObjectIdenticalTo: repl] == NSNotFound)
                [repl deleteDocument];
        }
    }
    return repls;
}



#pragma mark -
#pragma mark TRACKING CHANGES:


- (NSUInteger) lastSequenceNumber {
    if (!_lastSequenceNumberKnown) {
        _lastSequenceNumberKnown = YES;
        // Don't know the current sequence number, so ask for it:
        id seqObj = [[self GET].responseBody.fromJSON objectForKey: @"update_seq"];  // synchronous
        if ([seqObj isKindOfClass: [NSNumber class]])
            _lastSequenceNumber = [seqObj intValue];
    }
    return _lastSequenceNumber;
}


- (void) setLastSequenceNumber:(NSUInteger)lastSequenceNumber {
    _lastSequenceNumber = lastSequenceNumber;
    _lastSequenceNumberKnown = YES;
}


// <http://wiki.apache.org/couchdb/HTTP_database_API#Changes>


// This is just for unit tests to use.
- (void) onChange: (OnDatabaseChangeBlock)block {
    NSAssert(!_onChangeBlock, @"Sorry, only one onChange handler at a time");
    _onChangeBlock = [block copy];
}


// Part of <CouchChangeTrackerClient> protocol
- (void) changeTrackerReceivedChange: (NSDictionary*)change {
    // Get & check sequence number:
    NSNumber* sequenceObj = $castIf(NSNumber, [change objectForKey: @"seq"]);
    if (!sequenceObj)
        return;
    NSUInteger sequence = [sequenceObj intValue];
    if (sequence <= _lastSequenceNumber)
        return;
    
    if (_busyDocuments.count) {
        // Don't process changes while I have pending PUT/POST/DELETEs out. Wait till they finish,
        // so I don't think the change is external.
        COUCHLOG2(@"CouchDatabase deferring change (seq %lu) till operations finish", 
              (unsigned long)sequence);
        if (!_deferredChanges)
            _deferredChanges = [[NSMutableArray alloc] init];
        [_deferredChanges addObject: change];
        return;
    }
    
    self.lastSequenceNumber = sequence;
    
    // Get document:
    NSString* docID = [change objectForKey: @"id"];
    CouchDocument* document = [self documentWithID: docID];
    
    // Notify!
    NSDictionary* userInfo = nil;
    BOOL isExternalChange = [document notifyChanged: change];
    if (isExternalChange) {
        COUCHLOG(@"CouchDatabase: External change with seq=%lu", (unsigned long)sequence);
        userInfo = [NSDictionary dictionaryWithObject: (id)kCFBooleanTrue forKey: @"external"];
    }

    if (_onChangeBlock)
        ((OnDatabaseChangeBlock)_onChangeBlock)(document, isExternalChange);
    
    // Post a database-changed notification, but only post one per runloop cycle by using
    // a notification queue. If the current notification has the "external" flag, make sure it
    // gets posted by clearing any pending instance of the notification that doesn't have the flag.
    NSNotification* n = [NSNotification notificationWithName: kCouchDatabaseChangeNotification
                                                      object: self
                                                    userInfo: userInfo];
    NSNotificationQueue* queue = [NSNotificationQueue defaultQueue];
    if (isExternalChange)
        [queue dequeueNotificationsMatching: n coalesceMask: NSNotificationCoalescingOnSender];
    [queue enqueueNotification: n
                  postingStyle: NSPostASAP 
                  coalesceMask: NSNotificationCoalescingOnSender
                      forModes: [NSArray arrayWithObject: NSRunLoopCommonModes]];
}


- (void) processDeferredChanges {
    NSArray* changes = [_deferredChanges autorelease];
    _deferredChanges = nil;
    
    for (NSDictionary* change in changes) {
        [self changeTrackerReceivedChange: change];
    }
}


// Part of <CouchChangeTrackerClient> protocol
- (NSURLCredential*) authCredential {
    return [self credentialForOperation: nil];
}


- (BOOL) tracksChanges {
    return _tracker != nil;
}


- (void) setTracksChanges: (BOOL)track {
    if (track && !_tracker) {
        _tracker = [[CouchChangeTracker alloc] initWithDatabaseURL: self.URL
                                                              mode: kContinuous
                                                      lastSequence: self.lastSequenceNumber
                                                            client: self];
        [_tracker start];
    } else if (!track && _tracker) {
        [_tracker stop];
        [_tracker release];
        _tracker = nil;
    }
}


@end
