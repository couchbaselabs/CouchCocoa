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

@property (readonly, copy) NSString* currentRevisionID;

- (CouchRevision*) currentRevision;
- (CouchRevision*) revisionWithID: (NSString*)revisionID;

- (NSArray*) getRevisionHistory;

#pragma mark PROPERTIES:

/** These are the app-defined properties of the document, without the CouchDB-defined special properties whose names begin with "_".
    (If you want the entire set of properties returned by the server, use the inherited -representedObject property.)
    This is shorthand for self.currentRevision.properties. */
@property (readonly, copy) NSDictionary* properties;

/** Shorthand for [self.properties objectForKey: key]. */
- (id) propertyForKey: (NSString*)key;

/** Updates the document with new properties.
    This is asynchronous. Watch response for conflicts! */
- (RESTOperation*) putProperties: (NSDictionary*)properties;

@end


extern NSString* const kCouchDocumentChangeNotification;
