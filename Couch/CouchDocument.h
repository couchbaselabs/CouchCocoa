//
//  CouchDocument.h
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
@class CouchAttachment, CouchDatabase, CouchRevision;


/** A CouchDB document, aka "record" aka "row".
    Note: Never alloc/init a CouchDocument directly. Instead get it from the database by calling -documentWithID: or -untitledDocument. */
@interface CouchDocument : CouchResource
{
    @private
    id _modelObject;
    BOOL _isDeleted;
    NSString* _currentRevisionID;
    CouchRevision* _currentRevision;
}

/** The unique ID of this document; its key in the database. */
@property (readonly) NSString* documentID;

/** The document ID abbreviated to a maximum of 10 characters including ".." in the middle.
    Useful for logging or debugging. */
@property (readonly) NSString* abbreviatedID;

/** YES if the document has been deleted from the database. */
@property (readonly) BOOL isDeleted;

/** Optional reference to an application-defined model object representing this document.
    This property is unused and uninterpreted by CouchCocoa; use it for whatever you want.
    Note that this is not a strong/retained reference. */
@property (assign) id modelObject;

#pragma mark REVISIONS:

/** The ID of the current revision (if known; else nil). */
@property (readonly, copy) NSString* currentRevisionID;

/** The current/latest revision. This object is cached.
    This method may need to make a synchronous call to the server to fetch the revision, if its revision ID is not yet known. */
- (CouchRevision*) currentRevision;

/** The revision with the specified ID.
    This is merely a factory method that doesn't fetch anything from the server,
    or even verify that the ID is valid. */
- (CouchRevision*) revisionWithID: (NSString*)revisionID;

/** Returns an array of available revisions.
    The ordering is essentially arbitrary, but usually chronological (unless there has been merging with changes from another server.)
    The number of historical revisions available may vary; it depends on how recently the database has been compacted. You should not rely on earlier revisions being available, except for those representing unresolved conflicts. */
- (NSArray*) getRevisionHistory;

#pragma mark PROPERTIES:

/** The contents of the current revision of the document.
    This is shorthand for self.currentRevision.properties.
    Any keys in the dictionary that begin with "_", such as "_id" and "_rev", contain CouchDB metadata. */
@property (readonly, copy) NSDictionary* properties;

/** The user-defined properties, without the ones reserved by CouchDB.
    This is based on -properties, with every key whose name starts with "_" removed. */
@property (readonly, copy) NSDictionary* userProperties;

/** Shorthand for [self.properties objectForKey: key]. */
- (id) propertyForKey: (NSString*)key;

/** Updates the document with new properties, creating a new revision (Asynchronous.)
    The properties dictionary needs to contain a "_rev" key whose value is the current revision's ID; the dictionary returned by -properties will already have this, so if you modify that dictionary you're OK. The exception is if this is a new document, as there is no current revision, so no "_rev" key is needed.
    If the PUT succeeds, the operation's resultObject will be set to the new CouchRevision.
    You should be prepared for the operation to fail with a 412 status, indicating that a newer revision has already been added by another client.
    In this case you need to call -currentRevision again, to get that newer revision, incorporate any changes into your properties dictionary, and try again. (This is not the same as a conflict resulting from synchronization. Those conflicts result in multiple versions of a document appearing in the database; but in this case, you were prevented from creating a conflict.) */
- (RESTOperation*) putProperties: (NSDictionary*)properties;

#pragma mark CONFLICTS:

/** Returns an array of revisions that are currently in conflict, in no particular order.
    If there is no conflict, returns an array of length 1 containing only the current revision.
    Returns nil if an error occurs. */
- (NSArray*) getConflictingRevisions;

/** Resolves a conflict by choosing one existing revision as the winner.
    (This is the same as calling -resolveConflictingRevisions:withProperties:, passing in
    winningRevision.properties.)
    @param conflicts  The array of conflicting revisions as returned by -getConflictingRevisions.
    @param winningRevision  The revision from 'conflicts' whose properties should be used. */
- (RESTOperation*) resolveConflictingRevisions: (NSArray*)conflicts 
                                  withRevision: (CouchRevision*)winningRevision;

/** Resolves a conflict by creating a new winning revision from the given properties.
    @param conflicts  The array of conflicting revisions as returned by -getConflictingRevisions.
    @param properties  The properties to store into the document to resolve the conflict. */
- (RESTOperation*) resolveConflictingRevisions: (NSArray*)conflicts
                                withProperties: (NSDictionary*)properties;

@end


/** This notification is posted by a CouchDocument in response to an external change (as reported by the _changes feed.)
    It is not sent in response to 'local' changes made by this CouchDatabase's object tree.
    It will not be sent unless change-tracking is enabled in its parent CouchDatabase. */
extern NSString* const kCouchDocumentChangeNotification;


@protocol CouchDocumentModel <NSObject>
/** If a CouchDocument's modelObject implements this method, it will be called whenever the document posts a kCouchDocumentChangeNotification. */
- (void) couchDocumentChanged: (CouchDocument*)doc;
@end
