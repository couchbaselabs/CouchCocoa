//
//  CouchServer.m
//  CouchCocoa
//
//  Created by Jens Alfke on 5/26/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CouchServer.h"

#import "CouchInternal.h"
#import "RESTCache.h"


static NSString* const kLocalServerURL = @"http://127.0.0.1:5984/";


int gCouchLogLevel = 0;


@interface CouchServer ()
@property (nonatomic, readwrite, retain) NSArray* activeTasks;
@end


@implementation CouchServer


- (id) initWithURL: (NSURL*)url {
    return [super initWithURL: url];
}


/** Without URL, connects to localhost on default port */
- (id) init {
    return [self initWithURL:[NSURL URLWithString: kLocalServerURL]];
}


- (void)dealloc {
    [_activeTasks release];
    [_activityRsrc release];
    [_dbCache release];
    [super dealloc];
}


- (RESTResource*) childWithPath: (NSString*)name {
    return [[[CouchResource alloc] initWithParent: self relativePath: name] autorelease];
}


- (NSString*) getVersion: (NSError**)outError {
    RESTOperation* op = [self GET];
    [op wait];
    if (outError)
        *outError = op.error;
    return [[op.responseBody.fromJSON objectForKey: @"version"] description]; // Blocks!
}


- (NSArray*) generateUUIDs: (NSUInteger)count {
    NSDictionary* params = [NSDictionary dictionaryWithObject:
                                    [NSNumber numberWithUnsignedLong: count]
                                                       forKey: @"?count"];
    RESTOperation* op = [[self childWithPath: @"_uuids"] sendHTTP: @"GET" parameters: params];
    return [op.responseBody.fromJSON objectForKey: @"uuids"];
}


- (NSArray*) getDatabases {
    RESTOperation* op = [[self childWithPath: @"_all_dbs"] GET];
    NSArray* names = $castIf(NSArray, op.responseBody.fromJSON); // Blocks!
    return [names rest_map: ^(id name) {
        return [name isKindOfClass:[NSString class]] ? [self databaseNamed: name] : nil;
    }];
}


- (CouchDatabase*) databaseNamed: (NSString*)name {
    CouchDatabase* db = (CouchDatabase*) [_dbCache resourceWithRelativePath: name];
    if (!db) {
        db = [[CouchDatabase alloc] initWithParent: self relativePath: name];
        if (!db)
            return nil;
        if (!_dbCache)
            _dbCache = [[RESTCache alloc] initWithRetainLimit: 0];
        [_dbCache addResource: db];
        [db release];
    }
    return db;
}


@synthesize activeTasks=_activeTasks;


- (void) pollActivity {
    if (!_activityRsrc) {
        _activityRsrc = [[RESTResource alloc] initWithParent:self relativePath:@"_active_tasks"];
    }
    RESTOperation* op = [_activityRsrc GET];
    [op onCompletion: ^{
        [_activityRsrc cacheResponse: op];
        NSArray* tasks = $castIf(NSArray, op.responseBody.fromJSON);
        if (tasks && ![tasks isEqual: _activeTasks]) {
            COUCHLOG(@"CouchServer: activeTasks = %@", tasks);
            self.activeTasks = tasks;    // Triggers KVO notification
        }
    }];
}


- (void) setActivityPollInterval: (NSTimeInterval)interval {
    if (interval != self.activityPollInterval) {
        [_activityPollTimer invalidate];
        [_activityPollTimer release];
        if (interval > 0) {
            _activityPollTimer = [[NSTimer scheduledTimerWithTimeInterval: interval
                                                                   target: self 
                                                                 selector: @selector(pollActivity)
                                                                 userInfo: NULL
                                                                  repeats: YES] retain];
            [self pollActivity];
        } else {
            _activityPollTimer = nil;
        }
    }
}


- (NSTimeInterval) activityPollInterval {
    return _activityPollTimer ? _activityPollTimer.timeInterval : 0.0;
}


@end
