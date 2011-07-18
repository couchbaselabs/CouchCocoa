//
//  CouchInternal.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/26/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "Couch.h"
#import "RESTInternal.h"


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
- (void) loadCurrentRevisionFrom: (NSDictionary*)contents;
- (void) bulkSaveCompleted: (NSDictionary*) result;
- (BOOL) notifyChanged: (NSDictionary*)change;
@end


@interface CouchRevision ()
- (id) initWithDocument: (CouchDocument*)document revisionID: (NSString*)revisionID;
- (id) initWithDocument: (CouchDocument*)document properties: (NSDictionary*)contents;
- (id) initWithOperation: (RESTOperation*)operation;
@property (readwrite) BOOL isDeleted;
@property (readwrite, copy) NSDictionary* properties;
@end


/** A query that allows custom map and reduce functions to be supplied at runtime.
    Usually created by calling -[CouchDatabase slowQueryWithMapFunction:]. */
@interface CouchFunctionQuery : CouchQuery
{
    NSDictionary* _viewDefinition;
}

- (id) initWithDatabase: (CouchDatabase*)db
         viewDefinition: (struct CouchViewDefinition)definition;

@end
