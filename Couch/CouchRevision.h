//
//  CouchRevision.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/28/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchResource.h"
@class CouchAttachment, CouchDocument, RESTOperation;

/** A single revision of a CouchDocument. */
@interface CouchRevision : CouchResource
{
    @private
    NSDictionary* _properties;
    BOOL _isDeleted;
}

@property (readonly) CouchDocument* document;
@property (readonly) NSString* documentID;
@property (readonly) NSString* revisionID;

/** Is this the current/latest revision of its document? */
@property (readonly) BOOL isCurrent;

/** Does this revision mark the deletion of its document? */
@property (readonly) BOOL isDeleted;

#pragma mark PROPERTIES

/** These are the app-defined properties of the document, without the CouchDB-defined special properties whose names begin with "_". */
@property (readonly, copy) NSDictionary* properties;

/** Shorthand for [self.properties objectForKey: key]. */
- (id) propertyForKey: (NSString*)key;

/** The document as returned from the server and parsed from JSON.
    Keys beginning with "_" are defined and reserved by CouchDB; others are app-specific.
    For most purposes you probably want to use the -properties property instead. */
@property (readonly) NSDictionary* fromJSON;


/** Creates a new revision with the given properties. This is asynchronous. Watch response for conflicts! */
- (RESTOperation*) putProperties: (NSDictionary*)properties;


#pragma mark ATTACHMENTS

/** The names of all attachments (array of strings). */
@property (readonly) NSArray* attachmentNames;

/** Looks up the attachment with the given name (without fetching its contents). */
- (CouchAttachment*) attachmentNamed: (NSString*)name;

/** Creates a new attachment object, but doesn't write it to the database yet.
    To actually create the attachment, you'll need to call -PUT on the CouchAttachment. */
- (CouchAttachment*) createAttachmentWithName: (NSString*)name type: (NSString*)contentType;


@end
