//
//  RESTCache.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/17/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "RESTCache.h"
#import "RESTInternal.h"


static const NSUInteger kDefaultRetainLimit = 50;


@implementation RESTCache


- (id)init {
    return [self initWithRetainLimit: kDefaultRetainLimit];
}


- (id)initWithRetainLimit: (NSUInteger)retainLimit {
    self = [super init];
    if (self) {
#ifdef TARGET_OS_IPHONE
        // Construct a CFDictionary that doesn't retain its values:
        CFDictionaryValueCallBacks valueCB = kCFTypeDictionaryValueCallBacks;
        valueCB.retain = NULL;
        valueCB.release = NULL;
        _map = (NSMutableDictionary*)CFDictionaryCreateMutable(
                       NULL, 100, &kCFCopyStringDictionaryKeyCallBacks, &valueCB);
#else
        // Construct an NSMapTable that doesn't retain its values:
        _map = [[NSMapTable alloc] initWithKeyOptions: NSPointerFunctionsStrongMemory |
                                                       NSPointerFunctionsObjectPersonality
                                         valueOptions: NSPointerFunctionsZeroingWeakMemory |
                                                       NSPointerFunctionsObjectPersonality
                                             capacity: 100];
#endif
        if (retainLimit > 0) {
            _cache = [[NSCache alloc] init];
            _cache.countLimit = retainLimit;
        }
    }
    return self;
}


- (void)dealloc {
    for (RESTResource* doc in _map.objectEnumerator)
        doc.owningCache = nil;
    [_map release];
    [_cache release];
    [super dealloc];
}


- (void) addResource: (RESTResource*)resource {
    resource.owningCache = self;
    NSString* key = resource.relativePath;
    [_map setObject: resource forKey: key];
    if (_cache)
        [_cache setObject: resource forKey: key];
    else
        [[resource retain] autorelease];
}


- (RESTResource*) resourceWithRelativePath: (NSString*)docID {
    RESTResource* doc = [_map objectForKey: docID];
    if (doc && _cache && ![_cache objectForKey:docID])
        [_cache setObject: doc forKey: docID];  // re-add doc to NSCache since it's recently used
    return doc;
}


- (void) forgetResource: (RESTResource*)resource {
    RESTCache* cache = resource.owningCache;
    if (cache) {
        NSAssert(cache == self, @"Removing object from the wrong cache");
        resource.owningCache = nil;
        [_map removeObjectForKey: resource.relativePath];
    }
}


- (void) resourceBeingDealloced:(RESTResource*)resource {
    [_map removeObjectForKey: resource.relativePath];
}


- (void) forgetAllResources {
    [_map removeAllObjects];
    [_cache removeAllObjects];
}


@end
