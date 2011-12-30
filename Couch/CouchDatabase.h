//
//  CouchDatabase.h
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

#import "CouchResource.h"
#import "CouchReplication.h"
@class RESTCache, CouchChangeTracker, CouchDocument, CouchDesignDocument, CouchPersistentReplication, CouchQuery, CouchServer;


/** A CouchDB database; contains CouchDocuments.
    The CouchServer is the factory object for CouchDatabases. */
@interface CouchDatabase : CouchResource
{
    @private
    RESTCache* _docCache;
    NSCountedSet* _busyDocuments;
    CouchChangeTracker* _tracker;
    NSUInteger _lastSequenceNumber;
    BOOL _lastSequenceNumberKnown;
    id _onChangeBlock;
    NSMutableArray* _deferredChanges;
}

/** A convenience to instantiate a CouchDatabase directly from a URL, without having to first instantiate a CouchServer.
    Unlike CouchServer's -databaseNamed: method, if you call this twice with the same URL you _will_ get two distinct CouchDatabase objects (with two distinct CouchServers as parents.) */
+ (CouchDatabase*) databaseWithURL: (NSURL*)databaseURL;

/** A convenience to instantiate a CouchDatabase directly from a name and a server URL, without having to first instantiate a CouchServer.
    Unlike CouchServer's -databaseNamed: method, if you call this twice with the same URL/name you _will_ get two distinct CouchDatabase objects (with two distinct CouchServers as parents.) */
+ (CouchDatabase*) databaseNamed: (NSString*)databaseName
                 onServerWithURL: (NSURL*)serverURL;

@property (readonly) CouchServer* server;

/** Creates the database on the server.
    Fails with an HTTP status 412 (Conflict) if a database with this name already exists. */
- (RESTOperation*) create;

/** Creates the database on the server, if it doesn't already exist (Synchronous).
    This calls -create and waits for completion, but ignores HTTP status 412. */
- (BOOL) ensureCreated: (NSError**)outError;

/** Compacts the database, freeing up disk space by deleting old revisions of documents.
    This should be run periodically, especially after making a lot of changes.
    Note: The REST operation completes as soon as the server starts compacting, but the actual compaction will run asynchronously and may take a while. */
- (RESTOperation*) compact;

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
    @param properties  An array specifying the new properties of each item in revisions. Each item must be an NSDictionary, or an NSNull object which means to delete the corresponding document.
    @param revisions  A parallel array to 'properties', containing each CouchRevision or CouchDocument to be updated. Can be nil, in which case the method acts as described in the docs for -putChanges:. */
- (RESTOperation*) putChanges: (NSArray*)properties toRevisions: (NSArray*)revisions;

/** Bulk-writes multiple documents in one HTTP call.
    Each property dictionary with an "_id" key will update the existing document with that ID, or create a new document with that ID. A dictionary without an "_id" key will always create a new document with a server-assigned unique ID.
    If a dictionary updates an existing document, it must also have an "_rev" key that contains the document's current revision ID.
    The write is asynchronous, but after the returned operation finishes, its -resultObject will be an NSArray of CouchDocuments.
    @param properties  Array of NSDictionaries, each one the properties of a document. */
- (RESTOperation*) putChanges: (NSArray*)properties;

/** Deletes the given revisions. */
- (RESTOperation*) deleteRevisions: (NSArray*)revisions;

/** Deletes the given documents. */
- (RESTOperation*) deleteDocuments: (NSArray*)documents;

/** Empties the cache of recently used CouchDocument objects.
    API calls will now instantiate and return new instances. */
- (void) clearDocumentCache;

#pragma mark QUERIES & DESIGN DOCUMENTS:

/** Returns a query that runs custom map/reduce functions.
    This is very slow compared to a precompiled view and should only be used for testing.
    @param map  The map function source. Must not be nil.
    @param reduce  The reduce function source, or nil for none.
    @param language  The language of the functions, or nil for JavaScript. */
- (CouchQuery*) slowQueryWithMap: (NSString*)map
                          reduce: (NSString*)reduce
                        language: (NSString*)language;

/** Convenience method that creates a custom query from a JavaScript map function. */
- (CouchQuery*) slowQueryWithMap: (NSString*)map;

/** Instantiates a CouchDesignDocument object with the given ID.
    Makes no server calls; a design document with that ID doesn't even need to exist yet.
    CouchDesignDocuments are cached, so there will never be more than one instance (in this database) at a time with the same name. */
- (CouchDesignDocument*) designDocumentWithName: (NSString*)name;

#pragma mark CHANGE TRACKING:

/** Controls whether document change-tracking is enabled.
    It's off by default.
    Only external changes are tracked, not ones made through this database object and its children. This is useful in handling synchronization, or multi-client access to the same database, or on application relaunch to detect changes made after it last quit.
    Turning tracking on creates a persistent socket connection to the database, and will post potentially a lot of notifications, so don't turn it on unless you're actually going to use the notifications. */
@property BOOL tracksChanges;

/** The last change sequence number received from the database.
    If this is not known yet, the current value will be fetched via a synchronous query.
    You can save the current value on quit, and restore it on relaunch before enabling change tracking, to get notifications of all changes that have occurred in the meantime. */
@property NSUInteger lastSequenceNumber;

#pragma mark REPLICATION & SYNCHRONIZATION:

/** Triggers replication from a source database, to this database.
    @param sourceURL  The URL of the database to replicate from.
    @param options  Zero or more option flags affecting the replication.
    @return  The CouchReplication object managing the replication. It will already have been started. */
- (CouchReplication*) pullFromDatabaseAtURL: (NSURL*)sourceURL
                                    options: (CouchReplicationOptions)options;

/** Triggers replication from this database to a target database.
    @param targetURL  The URL of the database to replicate to.
    @param options  Zero or more option flags affecting the replication.
    @return  The CouchReplication object managing the replication. It will already have been started. */
- (CouchReplication*) pushToDatabaseAtURL: (NSURL*)targetURL
                                  options: (CouchReplicationOptions)options;

/** Configures this database to replicate bidirectionally (sync to and from) a database at the given URL.
    @param otherURL  The URL of the other database, or nil to indicate no replication.
    @param exclusively  If YES, any existing replications to or from other URLs will be removed.
    @return  A two-element NSArray whose values are the CouchPersistentReplications from and to the other URL, respectively. Returns nil if no target URL was given, or on failure. */
- (NSArray*) replicateWithURL: (NSURL*)otherURL exclusively: (BOOL)exclusively;

/** Creates a persistent replication from a database (a pull).
    Returns an object representing this replication. If a replication from this URL already exists, the configuration is unchanged. */
- (CouchPersistentReplication*) replicationFromDatabaseAtURL: (NSURL*)sourceURL;

/** Creates a persistent replication to a database (a push).
    Returns an object representing this replication. If a replication from this URL already exists, the configuration is unchanged. */
- (CouchPersistentReplication*) replicationToDatabaseAtURL: (NSURL*)targetURL;

/** All currently configured persistent replications involving this database, as CouchPersistentReplication objects. */
@property (readonly) NSArray* replications;

@end


/** This notification is posted by a CouchDatabase in response to document changes.
    It will not be sent unless tracksChanges is enabled.
    Only one notification is posted per runloop cycle, no matter how many documents changed.
    If a change was not made by a CouchDocument belonging to this CouchDatabase (i.e. it came
    from another process or from a "pull" replication), the notification's userInfo dictionary will
    contain an "external" key with a value of YES. */
extern NSString* const kCouchDatabaseChangeNotification;
