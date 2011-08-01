//
//  CouchRevision.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/28/11.
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
@class CouchAttachment, CouchDocument, RESTOperation;

/** A single revision of a CouchDocument. */
@interface CouchRevision : CouchResource
{
    @private
    NSDictionary* _properties;
    BOOL _isDeleted;
}

/** The document this is a revision of. */
@property (readonly) CouchDocument* document;

/** The document's ID. */
@property (readonly) NSString* documentID;

/** The ID of this revision. */
@property (readonly) NSString* revisionID;

/** Is this the current/latest revision of its document? */
@property (readonly) BOOL isCurrent;

/** Does this revision mark the deletion of its document? */
@property (readonly) BOOL isDeleted;


#pragma mark PROPERTIES

/** The document as returned from the server and parsed from JSON. (Synchronous)
    Keys beginning with "_" are defined and reserved by CouchDB; others are app-specific.
    The properties are cached for the lifespan of this object, so subsequent calls after the first are cheap.
    (This accessor is synchronous.) */
@property (readonly, copy) NSDictionary* properties;

/** The user-defined properties, without the ones reserved by CouchDB.
    This is based on -properties, with every key whose name starts with "_" removed. */
@property (readonly, copy) NSDictionary* userProperties;

/** Shorthand for [self.properties objectForKey: key]. (Synchronous) */
- (id) propertyForKey: (NSString*)key;

/** Has this object fetched its contents from the server yet? */
@property (readonly) BOOL propertiesAreLoaded;

/** Creates a new revision with the given properties.
    This is asynchronous. Watch response for conflict errors!
    If successful, the new CouchRevision will be available as the operation's resultObject. */
- (RESTOperation*) putProperties: (NSDictionary*)properties;

#pragma mark ATTACHMENTS

/** The names of all attachments (array of strings). */
@property (readonly) NSArray* attachmentNames;

/** Looks up the attachment with the given name (without fetching its contents). */
- (CouchAttachment*) attachmentNamed: (NSString*)name;

/** Creates a new attachment object, but doesn't write it to the database yet.
    To actually create the attachment, you'll need to call -PUT on the CouchAttachment.
    It's OK to call this with an attachment name that already exists; saving will overwrite the old attachment contents. */
- (CouchAttachment*) createAttachmentWithName: (NSString*)name type: (NSString*)contentType;


@end
