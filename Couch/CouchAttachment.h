//
//  CouchAttachment.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/26/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchResource.h"
@class CouchDocument;


/** A binary attachment to a document. */
@interface CouchAttachment : CouchResource
{
    @private
    NSString* _contentType;
}

- (id) initWithDocument: (CouchDocument*)document 
                   name: (NSString*)name
                   type: (NSString*)contentType;

@property (readonly) CouchDocument* document;
@property (readonly) NSString* name;
@property (readonly, copy) NSString* contentType;

/** Asynchronous setter for the body. (Use inherited -GET to get it.) */
- (RESTOperation*) PUT: (NSData*)body contentType: (NSString*)contentType;

/** Asynchronous setter for the body. (Use inherited -GET to get it.) */
- (RESTOperation*) PUT: (NSData*)body;

/** Synchronous accessor for the body.
    If the getter fails, it returns nil. The setter fails silently. */
@property (copy) NSData* body;

@end
