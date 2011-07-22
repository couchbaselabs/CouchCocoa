//
//  CouchResource.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/29/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "RESTResource.h"
@class CouchDatabase;


/** NSError domain string used for errors returned from the CouchDB server. */
extern NSString* const kCouchDBErrorDomain;


/** Superclass of CouchDB model classes. Adds Couch-specific error handling to RESTResource. */
@interface CouchResource : RESTResource

/** The owning database. */
@property (readonly) CouchDatabase* database;

@end
