//
//  CouchUser.h
//  CouchCocoa
//
//  Created by Fabien Franzen on 20-06-12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//
//  For more info: http://wiki.apache.org/couchdb/Security_Features_Overview
//

#import "CouchModel.h"

@interface CouchUser : CouchModel

/** Type is always 'user'. **/
@property (readonly) NSString* type;

/** Name is a lowercase string, also part of ID: org.couchdb.user:<name>. **/
@property (readonly) NSString* name;

/** Roles are the roles this user has. Defaults to empty array. **/
@property (copy) NSArray* roles;

/** This returns a CouchUser - does not make any server calls until needed. **/
+ (NSString*) userIDWithName:(NSString*)name;

/** The password value will be removed from the document once it's hashed on the server.
    It's not mandatory when creating a new CouchUser. Requires CouchDB >= 1.2.0. **/
- (void) setPassword:(NSString*)password;

@end
