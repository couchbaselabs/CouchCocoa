//
//  CouchDatabase.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/26/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchResource.h"
@class RESTCache, CouchChangeTracker, CouchDocument, CouchDesignDocument, CouchQuery, CouchServer;
struct CouchViewDefinition;


/** Type of block that's called when the database changes. */
typedef void (^OnDatabaseChangeBlock)(CouchDocument*);


/** A CouchDB database; contains CouchDocuments.
    The CouchServer is the factory object for CouchDatabases. */
@interface CouchDatabase : CouchResource
{
    @private
    RESTCache* _docCache;
    NSCountedSet* _busyDocuments;
    CouchChangeTracker* _tracker;
    NSUInteger _lastSequenceNumber;
    OnDatabaseChangeBlock _onChange;
    NSMutableArray* _deferredChanges;
}

@property (readonly) CouchServer* server;

/** Creates the database on the server. */
- (RESTOperation*) create;

/** Gets the current total number of documents. (Synchronous) */
- (NSInteger) getDocumentCount;

/** Instantiates a CouchDocument object with the given ID.
    Makes no server calls; a document with that ID doesn't even need to exist yet.
    CouchDocuments are cached, so there will never be more than one instance (in this database)
    at a time with the same documentID. */
- (CouchDocument*) documentWithID: (NSString*)docID;

/** Creates a CouchDocument object with no current ID.
    The first time you PUT to that document, it will be created on the server (via a POST). */
- (CouchDocument*) untitledDocument;

/** Returns a query that will fetch all documents in the database. */
- (CouchQuery*) getAllDocuments;

/** Returns a query that will fetch the documents with the given IDs. */
- (CouchQuery*) getDocumentsWithIDs: (NSArray*)docIDs;

/** Bulk-writes multiple documents in one HTTP call.
    Documents that don't exist on the server yet will be created. */
- (RESTOperation*) putChanges: (NSArray*)properties toRevisions: (NSArray*)revisions;

/** Empties the cache of recently used CouchDocument objects.
    API calls will now instantiate and return new instances. */
- (void) clearDocumentCache;

#pragma mark QUERIES & DESIGN DOCUMENTS:

/** Returns a query that runs custom map/reduce functions.
    This is very slow compared to a precompiled view and should only be used for testing. */
- (CouchQuery*) slowQueryWithViewDefinition:(struct CouchViewDefinition)definition;

/** Convenience method that creates a custom query from a JavaScript map function. */
- (CouchQuery*) slowQueryWithMapFunction: (NSString*)mapFunctionSource;

/** Instantiates a CouchDesignDocument object with the given ID.
    Makes no server calls; a design document with that ID doesn't even need to exist yet.
    CouchDesignDocuments are cached, so there will never be more than one instance (in this database) at a time with the same name. */
- (CouchDesignDocument*) designDocumentWithName: (NSString*)name;

#pragma mark CHANGE TRACKING:

/** Controls whether document change-tracking is enabled.
    It's off by default. Turning it on creates a long-lived socket connection to the database, and will post potentially a lot of notifications, so don't turn it on unless you're actually going to use the notifications. */
@property BOOL tracksChanges;

/** The last change sequence number received from the database.
    If this is not known yet, the current value will be fetched via a synchronous query.
    You can save the current value on quit, and restore it on relaunch before enabling change tracking, to get notifications of all changes that have occurred in the meantime. */
@property NSUInteger lastSequenceNumber;

/** The given block will be called every time a document change notification is received.
    It's not currently possible to register more than one block; each call overwrites the last.
    See also: kCouchDocumentChangeNotification. */
- (void) onChange: (OnDatabaseChangeBlock)block;


@end
