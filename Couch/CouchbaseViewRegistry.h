//
//  CouchViewRegistry.h
//  iErl14
//
//  Created by Jens Alfke on 10/3/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^CouchEmitBlock)(id key, id value);
typedef void (^CouchMapBlock)(NSDictionary* doc, CouchEmitBlock emit);
typedef id (^CouchReduceBlock)(NSArray* keys, NSArray* values, BOOL rereduce);

/** Central per-process registry for native map/reduce functions.
	Associates a key (a unique ID stored in the design doc as the "source" of the function)
	with a C block.
	This class is thread-safe. */
@interface CouchbaseViewRegistry : NSObject
{
    NSMutableDictionary* _mapBlocks, *_reduceBlocks;
}

+ (CouchbaseViewRegistry*) sharedInstance;

- (NSString*) generateKey;

- (void) registerMapBlock: (CouchMapBlock)block forKey: (NSString*)key;
- (void) registerReduceBlock: (CouchReduceBlock)block forKey: (NSString*)key;

- (CouchMapBlock) mapBlockForKey: (NSString*)key;
- (CouchReduceBlock) reduceBlockForKey: (NSString*)key;

@end
