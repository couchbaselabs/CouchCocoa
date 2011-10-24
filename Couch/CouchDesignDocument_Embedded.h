//
//  CouchDesignDocument_Embedded.h
//  CouchCocoa
//
//  Created by Jens Alfke on 10/3/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchDesignDocument.h"
#ifdef COUCHCOCOA_IMPL
#import "CouchbaseCallbacks.h"
#elif TARGET_OS_IPHONE
#import <Couchbase/CouchbaseCallbacks.h>
#else
#import <CouchbaseMac/CouchbaseCallbacks.h>
#endif


extern NSString* const kCouchLanguageObjectiveC;


#define MAPBLOCK(BLOCK) ^(NSDictionary* doc, void (^emit)(id key, id value)){BLOCK}
#define REDUCEBLOCK(BLOCK) ^id(NSArray* keys, NSArray* values, BOOL rereduce){BLOCK}
#define VALIDATIONBLOCK(BLOCK) ^BOOL(NSDictionary* doc, id<CouchbaseValidationContext> context)\
                                  {BLOCK}


/** Optional support for native Objective-C map/reduce functions.
    This is only available when talking to an embedded Couchbase database running in the same process as the app, e.g. Couchbase Mobile. */
@interface CouchDesignDocument (Embedded)

/** Defines or deletes a native view.
    The view's definition is given as an Objective-C block (or NULL to delete the view). The body of the block should call the 'emit' block (passed in as a paramter) for every key/value pair it wants to write to the view.
    Since the function itself is obviously not stored in the database (only a unique string idenfitying it), you must re-define the view on every launch of the app! If the database needs to rebuild the view but the function hasn't been defined yet, it will fail and the view will be empty, causing weird problems later on.
    It is very important that this block be a law-abiding map function! As in other languages, it must be a "pure" function, with no side effects, that always emits the same values given the same input document. That means that it should not access or change any external state; be careful, since blocks make that so easy that you might do it inadvertently!
    The block may be called on any thread, or on multiple threads simultaneously. This won't be a problem if the code is "pure" as described above, since it will as a consequence also be thread-safe. */
- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (CouchMapBlock)mapBlock;

/** Defines or deletes a native view with both a map and a reduce function.
    For details, read the documentation of the -defineViewNamed:mapBlock: method.*/
- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (CouchMapBlock)mapBlock
             reduceBlock: (CouchReduceBlock)reduceBlock;

/** An Objective-C block that can validate any document being added/updated to this database. */
@property (copy) CouchValidateUpdateBlock validationBlock;

@end
