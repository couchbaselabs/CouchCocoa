//
//  CouchInternal.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/26/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CouchCocoa.h"
#import "RESTInternal.h"


#define COUCHLOG  if(gCouchLogLevel < 1) ; else NSLog
#define COUCHLOG2 if(gCouchLogLevel < 2) ; else NSLog
#define COUCHLOG3 if(gCouchLogLevel < 3) ; else NSLog


/** Type of block that's called when the database changes. */
typedef void (^OnDatabaseChangeBlock)(CouchDocument*, BOOL externalChange);


@interface CouchAttachment ()
- (id) initWithParent: (CouchResource*)parent       // must be CouchDocument or CouchRevision
                 name: (NSString*)name
             metadata: (NSDictionary*)metadata;
@end


@interface CouchDatabase ()
- (void) documentAssignedID: (CouchDocument*)document;
- (void) beginDocumentOperation: (CouchResource*)resource;
- (void) endDocumentOperation: (CouchResource*)resource;
- (void) onChange: (OnDatabaseChangeBlock)block;  // convenience for unit tests
- (void) unretainDocumentCache;
- (void) changeTrackerReceivedChange: (NSDictionary*)change;
@end


@interface CouchDocument ()
- (id) initWithParent: (RESTResource*)parent
         relativePath: (NSString*)path
           documentID:(NSString *)documentID;
@property (readwrite, copy) NSString* currentRevisionID;
- (void) loadCurrentRevisionFrom: (CouchQueryRow*)row;
- (void) bulkSaveCompleted: (NSDictionary*) result forProperties: (NSDictionary*)properties;
- (BOOL) notifyChanged: (NSDictionary*)change;
@end


@interface CouchPersistentReplication ()
+ (CouchPersistentReplication*) createWithReplicatorDatabase: (CouchDatabase*)replicatorDB
                                                      source: (NSString*)source
                                                      target: (NSString*)target;
@end


@interface CouchRevision ()
- (id) initWithDocument: (CouchDocument*)document revisionID: (NSString*)revisionID;
- (id) initWithDocument: (CouchDocument*)document properties: (NSDictionary*)contents;
- (id) initWithOperation: (RESTOperation*)operation;
@property (readwrite) BOOL isDeleted;
@property (readwrite, copy) NSDictionary* properties;
@end


@interface CouchReplication ()
@property (nonatomic, readwrite) bool pull;
- (id) initWithDatabase: (CouchDatabase*)database
                 remote: (NSURL*)remote;
@end


@interface CouchPersistentReplication ()
@property (readonly) NSString* sourceURLStr;
@property (readonly) NSString* targetURLStr;
@end



@interface CouchServer ()
@property (readonly) CouchDatabase* replicatorDatabase;
@property (readonly) BOOL isEmbeddedServer;
- (CouchPersistentReplication*) replicationWithSource: (NSString*)source
                                               target: (NSString*)target;
- (void) registerActiveTask: (NSDictionary*)activeTask;
@end


/** A query that allows custom map and reduce functions to be supplied at runtime.
    Usually created by calling -[CouchDatabase slowQueryWithMapFunction:]. */
@interface CouchFunctionQuery : CouchQuery
{
    NSDictionary* _viewDefinition;
}

- (id) initWithDatabase: (CouchDatabase*)db
                    map: (NSString*)map
                 reduce: (NSString*)reduce
               language: (NSString*)language;
@end
