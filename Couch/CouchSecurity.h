//
//  CouchSecurity.h
//  CouchCocoa
//
//  Created by Fabien Franzen on 20-06-12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//
//  For more info: http://wiki.apache.org/couchdb/Security_Features_Overview
//

#import "CouchDynamicObject.h"


static NSString* const kSecurityAdminNamesKey = @"adminNames";
static NSString* const kSecurityAdminRolesKey = @"adminRoles";

static NSString* const kSecurityReaderNamesKey = @"readerNames";
static NSString* const kSecurityReaderRolesKey = @"readerRoles";

@class CouchUser, CouchResource, RESTOperation;

@interface CouchSecurity : CouchDynamicObject
{
    CouchResource* _resource;
    NSMutableDictionary* _properties;
}

@property (readonly) NSDictionary* properties;

/** Admins: can create/update Design Documents and manipulate the (per db) Couch Security Object.
    However, they cannot create or delete a database. **/
@property (copy,readwrite) NSArray* adminNames;
@property (copy,readwrite) NSArray* adminRoles;

/** Readers: can read and also create//update/delete documents (when validation permits), 
    but are not allowed to create/update Design Documents. **/
@property (copy,readwrite) NSArray* readerNames;
@property (copy,readwrite) NSArray* readerRoles;

/** The dropbox value is supported on Refuge and rcouch: 
    https://github.com/refuge/couch_core/commit/742846156eb5b881f88b88c6deecbef4e66ed2a0 **/
@property (readwrite) BOOL dropBox;

/** Save the current settings to the database. **/
- (RESTOperation*)update;

/** Helper methods to work with the nested collections of names and roles. **/
- (void)addObject:(id)obj forProperty:(NSString *)property;
- (void)removeObject:(id)obj forProperty:(NSString *)property;

@end
