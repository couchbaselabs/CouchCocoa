//
//  CouchResource.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/29/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "RESTResource.h"
@class CouchDatabase;


/** NSError domain string used for errors returned from the CouchDB server. */
extern NSString* const kCouchDBErrorDomain;


/** Superclass of CouchDB model classes. Adds Couch-specific error handling to RESTResource. */
@interface CouchResource : RESTResource

/** The owning database. */
@property (readonly) CouchDatabase* database;

@end
