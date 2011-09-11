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


@interface CouchAttachment ()
- (id) initWithRevision: (CouchRevision*)revision 
                   name: (NSString*)name
                   type: (NSString*)contentType;
@end


@interface CouchDatabase ()
- (void) documentAssignedID: (CouchDocument*)document;
- (void) receivedChangeLine: (NSData*)chunk;
- (void) beginDocumentOperation: (CouchResource*)resource;
- (void) endDocumentOperation: (CouchResource*)resource;
- (void) onChange: (OnDatabaseChangeBlock)block;  // convenience for unit tests
@end


@interface CouchDocument ()
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
- (id) initWithDatabase: (CouchDatabase*)database
                 remote: (NSURL*)remote
                   pull: (BOOL)pull
                options: (CouchReplicationOptions)options;
@end


@interface CouchServer ()
- (CouchPersistentReplication*) replicationWithSource: (NSString*)source
                                               target: (NSString*)target;
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
