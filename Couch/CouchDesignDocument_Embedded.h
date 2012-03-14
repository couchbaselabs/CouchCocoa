//
//  CouchDesignDocument_Embedded.h
//  CouchCocoa
//
//  Created by Jens Alfke on 10/3/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchDesignDocument.h"


typedef void (^CouchMapEmitBlock)(id key, id value);

/** A "map" function called when a document is to be added to a view.
    @param doc  The contents of the document being analyzed.
    @param emit  A block to be called to add a key/value pair to the view. Your block can call it zero, one or multiple times. */
typedef void (^CouchMapBlock)(NSDictionary* doc, CouchMapEmitBlock emit);

/** A "reduce" function called to summarize the results of a view.
	@param keys  An array of keys to be reduced (or nil if this is a rereduce).
	@param values  A parallel array of values to be reduced, corresponding 1::1 with the keys.
	@param rereduce  YES if the input values are the results of previous reductions.
	@return  The reduced value; almost always a scalar or small fixed-size object. */
typedef id (^CouchReduceBlock)(NSArray* keys, NSArray* values, BOOL rereduce);


/** Filter block, used in changes feeds and replication. */
typedef BOOL (^CouchFilterBlock) (NSDictionary* doc);


/** Context passed into a CouchValidationBlock. */
@protocol CouchValidationContext <NSObject>
/** The contents of the current revision of the document, or nil if this is a new document. */
@property (readonly) NSDictionary* currentRevision;

/** The type of HTTP status to report, if the validate block returns NO.
    The default value is 403 ("Forbidden"). */
@property int errorType;

/** The error message to return in the HTTP response, if the validate block returns NO.
    The default value is "invalid document". */
@property (copy) NSString* errorMessage;
@end


/** Validation block, used to approve revisions being added to the database. */
typedef BOOL (^CouchValidationBlock) (NSDictionary* doc,
                                      id<CouchValidationContext> context);


#define MAPBLOCK(BLOCK) ^(NSDictionary* doc, void (^emit)(id key, id value)){BLOCK}
#define REDUCEBLOCK(BLOCK) ^id(NSArray* keys, NSArray* values, BOOL rereduce){BLOCK}
#define VALIDATIONBLOCK(BLOCK) ^BOOL(NSDictionary* newRevision, id<CouchValidationContext> context)\
                                  {BLOCK}
#define FILTERBLOCK(BLOCK) ^BOOL(NSDictionary* revision) {BLOCK}


/** Optional support for native Objective-C map/reduce functions.
    This is only available when talking to an embedded Couchbase database running in the same process as the app, e.g. Couchbase Mobile. */
@interface CouchDesignDocument (Embedded)

/** Defines or deletes a native view.
    The view's definition is given as an Objective-C block (or NULL to delete the view). The body of the block should call the 'emit' block (passed in as a paramter) for every key/value pair it wants to write to the view.
    Since the function itself is obviously not stored in the database (only a unique string idenfitying it), you must re-define the view on every launch of the app! If the database needs to rebuild the view but the function hasn't been defined yet, it will fail and the view will be empty, causing weird problems later on.
    It is very important that this block be a law-abiding map function! As in other languages, it must be a "pure" function, with no side effects, that always emits the same values given the same input document. That means that it should not access or change any external state; be careful, since blocks make that so easy that you might do it inadvertently!
    The block may be called on any thread, or on multiple threads simultaneously. This won't be a problem if the code is "pure" as described above, since it will as a consequence also be thread-safe. */
- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (CouchMapBlock)mapBlock
                 version: (NSString*)version;

/** Defines or deletes a native view with both a map and a reduce function.
    For details, read the documentation of the -defineViewNamed:mapBlock: method.*/
- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (CouchMapBlock)mapBlock
             reduceBlock: (CouchReduceBlock)reduceBlock
                 version: (NSString*)version;

- (void) defineFilterNamed: (NSString*)filterName
                     block: (CouchFilterBlock)filterBlock;

/** An Objective-C block that can validate any document being added/updated/deleted in this database. */
- (void) setValidationBlock: (CouchValidationBlock)validationBlock;

@end
