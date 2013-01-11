//
//  RESTCache.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/17/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

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
    // Calling -release on the cache right now is dangerous because it might already be
    // flushing itself (which may have triggered deallocation of my owner and hence myself),
    // and deallocing it in the midst of that will cause it to deadlock. So delay the release.
    // See <https://github.com/couchbaselabs/TouchDB-iOS/issues/216>
    [_cache autorelease];
    [super dealloc];
}


- (void) addResource: (RESTResource*)resource {
    resource.owningCache = self;
    NSString* key = resource.relativePath;
    NSAssert(![_map objectForKey: key], @"Caching duplicate items for '%@': %p, now %p",
             key, [_map objectForKey: key], resource);
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


- (NSArray*) allCachedResources {
    return _map.allValues;
}


- (void) unretainResources {
    [_cache removeAllObjects];
}


- (void) forgetAllResources {
    [_map removeAllObjects];
    [_cache removeAllObjects];
}


@end
