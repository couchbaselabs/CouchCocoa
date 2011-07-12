//
//  CouchDocument.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/26/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchResource.h"
@class CouchAttachment, CouchDatabase, CouchRevision;


/** A CouchDB document, aka "record" aka "row".
    Note: Never alloc/init a CouchDocument directly. Instead get it from the database by calling -documentWithID: or -untitledDocument. */
@interface CouchDocument : CouchResource
{
    @private
    BOOL _isDeleted;
    NSString* _currentRevisionID;
    CouchRevision* _currentRevision;
}


@property (readonly) NSString* documentID;
@property (readonly) BOOL isDeleted;

#pragma mark REVISIONS:

/** The ID of the current revision (if known). */
@property (readonly, copy) NSString* currentRevisionID;

/** The current/latest revision. This object is cached. */
- (CouchRevision*) currentRevision;

/** The revision with the specified ID.
    This is merely a factory method that doesn't fetch anything from the server,
    or even verify that the ID is valid. */
- (CouchRevision*) revisionWithID: (NSString*)revisionID;

/** Returns an array of available revisions, in basically forward chronological order. */
- (NSArray*) getRevisionHistory;

#pragma mark PROPERTIES:

/** These are the app-defined properties of the document, without the CouchDB-defined special properties whose names begin with "_".
    This is shorthand for self.currentRevision.properties.
    (If you want the entire document object returned by the server, get the revision's -contents property.) */
@property (readonly, copy) NSDictionary* properties;

/** Shorthand for [self.properties objectForKey: key]. */
- (id) propertyForKey: (NSString*)key;

/** Updates the document with new properties.
    This is asynchronous. Watch response for conflicts! */
- (RESTOperation*) putProperties: (NSDictionary*)properties;

@end


/** This notification is posted by a CouchDocument in response to an external change (as reported by the _changes feed.)
    It is not sent in response to 'local' changes made by this CouchDatabase's object tree.
    It will not be sent unless change-tracking is enabled in its parent CouchDatabase. */
extern NSString* const kCouchDocumentChangeNotification;
