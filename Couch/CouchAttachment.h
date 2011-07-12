//
//  CouchAttachment.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/26/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

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

/** The attachment's URL without the revision ID.
    This URL will always resolve to the current revision of the attachment. */
@property (readonly) NSURL* unversionedURL;

/** Asynchronous setter for the body. (Use inherited -GET to get it.) */
- (RESTOperation*) PUT: (NSData*)body contentType: (NSString*)contentType;

/** Asynchronous setter for the body. (Use inherited -GET to get it.) */
- (RESTOperation*) PUT: (NSData*)body;

@end
