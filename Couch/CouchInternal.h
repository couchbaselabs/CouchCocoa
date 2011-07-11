//
//  CouchInternal.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/26/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "Couch.h"
#import "RESTInternal.h"


@interface CouchDatabase (Private)
- (void) documentAssignedID: (CouchDocument*)document;
- (void) receivedChangeLine: (NSData*)chunk;
@end


@interface CouchDocument (Private)
- (void) bulkSaveCompleted: (NSDictionary*) result;
@property (readwrite, copy) id representedObject;
- (BOOL) notifyChanged: (NSDictionary*)change;
@end


@interface CouchResource (Private)
/** Are this resource's contents always expected to be JSON?
    Default implementation returns YES; overridden by CouchAttachment to return NO. */
@property (readonly) BOOL contentsAreJSON;
@end


@interface CouchRevision (Private)
- (id) initWithDocument: (CouchDocument*)document revisionID: (NSString*)revisionID;
- (id) initWithDocument: (CouchDocument*)document contents: (NSDictionary*)contents;
- (id) initWithOperation: (RESTOperation*)operation;
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
