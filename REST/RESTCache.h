//
//  RESTCache.h
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

#import <Foundation/Foundation.h>
@class RESTResource;


/** An in-memory cache of RESTResource objects.
    It keeps track of all added resources as long as anything else has retained them,
    and it keeps a certain number of recently-accessed resources with no external references.
    It's intended for use by a parent resource, to cache its children.
 
    Important:
    * It should contain only direct sibling objects, as it assumes that their -relativePath property values are all different.
    * A RESTResource can belong to only one RESTCache at a time. */
@interface RESTCache : NSObject
{
    @private
#ifdef TARGET_OS_IPHONE
    NSMutableDictionary* _map;
#else
    NSMapTable* _map;
#endif
    NSCache* _cache;
}

- (id) init;
- (id) initWithRetainLimit: (NSUInteger)retainLimit;

/** Adds a resource to the cache.
    Does nothing if the resource is already in the cache.
    An exception is raised if the resource is already in a different cache. */
- (void) addResource: (RESTResource*)resource;

/** Looks up a resource given its -relativePath property. */
- (RESTResource*) resourceWithRelativePath: (NSString*)relativePath;

/** Removes a resource from the cache.
    Does nothing if the resource is not cached.
    An exception is raised if the resource is already in a different cache. */
- (void) forgetResource: (RESTResource*)resource;

/** Removes all resources from the cache. */
- (void) forgetAllResources;

@end
