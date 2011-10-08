//
//  CouchbaseCallbacks.h
//  iErl14
//
//  Created by Jens Alfke on 10/3/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol CouchbaseValidationContext;


typedef void (^CouchEmitBlock)(id key, id value);

/** A "map" function called when a document is to be added to a view.
	@param doc  The contents of the document being analyzed.
	@param emit  A block to be called to add a key/value pair to the view. Your block can call zero, one or multiple times. */
typedef void (^CouchMapBlock)(NSDictionary* doc, CouchEmitBlock emit);

/** A "reduce" function called to summarize the results of a view.
	@param keys  An array of keys to be reduced.
	@param values  A parallel array of values to be reduced, corresponding one-to-one with the keys.
	@param rereduce  YES if the input keys and values are the results of previous reductions.
	@return  The reduced value; almost always a scalar or small fixed-size object. */
typedef id (^CouchReduceBlock)(NSArray* keys, NSArray* values, BOOL rereduce);

/** Called to validate a document before it's added to the database.
	@param doc  The submitted document contents.
	@param context  Lets the block access relevant information and specify an error message.
	@return  YES to accept the document, NO to reject it. */
typedef BOOL (^CouchValidateUpdateBlock)(NSDictionary* doc,
                                         id<CouchbaseValidationContext> context);

/** Central per-process registry for native design-document functions.
	Associates a key (a unique ID stored in the design doc as the "source" of the function)
	with a C block.
	This class is thread-safe. */
@interface CouchbaseCallbacks : NSObject
{
    NSMutableArray* _registries;
}

+ (CouchbaseCallbacks*) sharedInstance;

- (NSString*) generateKey;

- (void) registerMapBlock: (CouchMapBlock)block forKey: (NSString*)key;
- (void) registerReduceBlock: (CouchReduceBlock)block forKey: (NSString*)key;
- (void) registerValidateUpdateBlock: (CouchValidateUpdateBlock)block forKey: (NSString*)key;

- (CouchMapBlock) mapBlockForKey: (NSString*)key;
- (CouchReduceBlock) reduceBlockForKey: (NSString*)key;
- (CouchValidateUpdateBlock) validateUpdateBlockForKey: (NSString*)key;

@end


/** Context passed into a CouchValidateUpdateBlock. */
@protocol CouchbaseValidationContext <NSObject>

/** The contents of the current revision of the document, or nil if this is a new document. */
@property (readonly) NSDictionary* currentRevision;

/** The name of the database being updated. */
@property (readonly) NSString* databaseName;

/** The name of the logged-in user, or nil if this is an anonymous request. */
@property (readonly) NSString* userName;

/** Does the user have admin privileges?
	(If the database is in the default "admin party" mode, this will be YES even when the userName is nil.) */
@property (readonly) BOOL isAdmin;

/** The database's security object, which assigns roles and privileges. */
@property (readonly) NSDictionary* security;

/** The type of error to report, if the validate block returns NO.
	The default value is "forbidden", which will result in an HTTP 403 status. */
@property (copy) NSString* errorType;

/** The error message to return in the HTTP response, if the validate block returns NO.
	The default value is "invalid document". */
@property (copy) NSString* errorMessage;
@end
