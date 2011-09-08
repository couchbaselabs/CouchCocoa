//
//  CouchAttachment.h
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
@class CouchDocument, CouchRevision;


/** A binary attachment to a document.
    Actually a CouchAttachment is a child of a CouchRevision, since attachments (like all document contents) are versioned. This means that each instance represents an attachment immutably as it appeared in one revision of its document. So if you PUT a change to an attachment, the updated attachment will have a new CouchAttachment object. */
@interface CouchAttachment : CouchResource
{
    @private
    NSString* _contentType;
}

/** The owning document revision. */
@property (readonly) CouchRevision* revision;

/** The owning document. */
@property (readonly) CouchDocument* document;

/** The filename (last URL path component). */
@property (readonly) NSString* name;

/** The MIME type of the contents. */
@property (readonly, copy) NSString* contentType;

/** Synchronous accessors for the body data.
    These are convenient, but have no means of error handling. */
@property (copy) NSData* body;

/** The attachment's URL without the revision ID.
    This URL will always resolve to the current revision of the attachment. */
@property (readonly) NSURL* unversionedURL;

/** Asynchronous setter for the body. (Use inherited -GET to get it.) */
- (RESTOperation*) PUT: (NSData*)body contentType: (NSString*)contentType;

/** Asynchronous setter for the body. (Use inherited -GET to get it.) */
- (RESTOperation*) PUT: (NSData*)body;

@end
