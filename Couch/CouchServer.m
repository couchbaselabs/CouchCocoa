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


- (id) copyWithZone: (NSZone*)zone {
    return [[[self class] alloc] initWithURL: self.URL];
}


- (void)dealloc {
    [_activeTasks release];
    [_activityRsrc release];
    [_replicationsQuery release];
    [_dbCache release];
    [super dealloc];
}


- (void) close {
    [_replicationsQuery release];
    _replicationsQuery = nil;
    for (CouchDatabase* db in _dbCache.allCachedResources)
        [db unretainDocumentCache];
}


- (CouchDatabase*) database {    // Overridden from CouchResource.
    return nil;
}


- (BOOL) isEmbeddedServer {
    return NO;  // CouchEmbeddedServer overrides this
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


- (NSString*) generateDocumentID {
    if (_newDocumentIDs.count == 0) {
        // As an optimization, request UUIDs from the server in packages of 10:
        NSArray* newIDs = [self generateUUIDs: 10];
        if (!newIDs) {
            // In an emergency, if we can't get IDs from the server, generate a UUID locally:
            CFUUIDRef uuid = CFUUIDCreate(NULL);
            CFStringRef cfStr = CFUUIDCreateString(NULL, uuid);
            CFRelease(uuid);
            return [(id)cfStr autorelease];
        }
        if (!_newDocumentIDs)
            _newDocumentIDs = [[NSMutableArray alloc] init];
        [_newDocumentIDs addObjectsFromArray: newIDs];
    }
    
    NSString* result = [[[_newDocumentIDs objectAtIndex: 0] retain] autorelease];
    [_newDocumentIDs removeObjectAtIndex: 0];
    return result;
}


- (NSArray*) getDatabases {
    RESTOperation* op = [[self childWithPath: @"_all_dbs"] GET];
    NSArray* names = $castIf(NSArray, op.responseBody.fromJSON); // Blocks!
    return [names rest_map: ^(id name) {
        return [name isKindOfClass:[NSString class]] ? [self databaseNamed: name] : nil;
    }];
}


- (Class) databaseClass {
    return [CouchDatabase class];
}


- (CouchDatabase*) databaseNamed: (NSString*)name {
    CouchDatabase* db = (CouchDatabase*) [_dbCache resourceWithRelativePath: name];
    if (!db) {
        db = [[[self databaseClass] alloc] initWithParent: self relativePath: name];
        if (!db)
            return nil;
        if (!_dbCache)
            _dbCache = [[RESTCache alloc] initWithRetainLimit: 0];
        [_dbCache addResource: db];
        [db release];
    }
    return db;
}

/** Same as -databaseNamed:. Enables "[]" access in Xcode 4.4+ */
- (id)objectForKeyedSubscript:(NSString*)key {
    return [self databaseNamed: key];
}



#pragma mark - REPLICATOR DATABASE:


- (CouchDatabase*) replicatorDatabase {
    return [self databaseNamed: @"_replicator"];
}


- (CouchLiveQuery*) replicationsQuery {
    if (!_replicationsQuery) {
        CouchDatabase* replicatorDB = [self replicatorDatabase];
        replicatorDB.tracksChanges = YES;
        _replicationsQuery = [[[replicatorDB getAllDocuments] asLiveQuery] retain];
        [_replicationsQuery wait];
    }
    return _replicationsQuery;
}


- (NSArray*) replications {
    return [self.replicationsQuery.rows.allObjects rest_map: ^(id row) {
        NSString* docID = [row documentID];
        if ([docID hasPrefix: @"_design/"] || [docID hasPrefix: @"_local/"])
            return (id)nil;
        return [CouchPersistentReplication modelForDocument: [row document]];
    }];
}


- (CouchPersistentReplication*) replicationWithSource: (NSString*)source
                                               target: (NSString*)target
{
    for (CouchPersistentReplication* repl in self.replications) {
        if ($equal(repl.sourceURLStr, source) && $equal(repl.targetURLStr, target))
            return repl;
    }
    return [CouchPersistentReplication createWithReplicatorDatabase: self.replicatorDatabase
                                                             source: source target: target];
}


#pragma mark - ACTIVITY MONITOR:


@synthesize activeTasks=_activeTasks;


- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath 
            options:(NSKeyValueObservingOptions)options context:(void *)context {
    if ([keyPath isEqualToString: @"activeTasks"]) {
        if (_activeTasksObserverCount++ == 0)
            [self setActivityPollInterval: 0.5];
    }
    [super addObserver: observer forKeyPath: keyPath options: options context: context];
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    if ([keyPath isEqualToString: @"activeTasks"]) {
        if (--_activeTasksObserverCount == 0)
            [self setActivityPollInterval: 0.0];
    }
    [super removeObserver: observer forKeyPath: keyPath];
}


- (void) checkActiveTasks {
    if (_activeTasksOp)
        return;  // already checking
    if (!_activityRsrc) {
        _activityRsrc = [[RESTResource alloc] initWithParent:self relativePath:@"_active_tasks"];
    }
    RESTOperation* op = [_activityRsrc GET];
    _activeTasksOp = op;
    [op onCompletion: ^{
        _activeTasksOp = nil;
        if (op.isSuccessful) {
            [_activityRsrc cacheResponse: op];
            NSArray* tasks = $castIf(NSArray, op.responseBody.fromJSON);
            if (tasks && ![tasks isEqual: _activeTasks]) {
                COUCHLOG2(@"CouchServer: activeTasks = %@", tasks);
                self.activeTasks = tasks;    // Triggers KVO notification
            }
        } else {
            Warn(@"CouchServer: pollActivity failed with %@", op.error);
            self.activityPollInterval = 0.0; // turn off polling
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
                                                                 selector: @selector(checkActiveTasks)
                                                                 userInfo: NULL
                                                                  repeats: YES] retain];
            [self checkActiveTasks];
        } else {
            _activityPollTimer = nil;
        }
    }
}


- (NSTimeInterval) activityPollInterval {
    return _activityPollTimer ? _activityPollTimer.timeInterval : 0.0;
}


- (void) registerActiveTask: (NSDictionary*)activeTask {
    // Adds an item to .activeTasks. Using this avoids a nasty race condition in classes (like
    // CouchReplication) that manage tasks and observe .activeTasks. If a task has a very short
    // lifespan, it might be already finished by the next time I poll _active_tasks, so it'll never
    // show up in the list. And since .activeTasks doesn't change, the observers won't be notified
    // and won't find out that the task is gone. By changing .activeTasks now to account for the
    // new task, we know it'll change again if the task is gone on the next poll, so the observer
    // will find out.
    NSMutableArray* tasks = _activeTasks ? [[_activeTasks mutableCopy] autorelease]
                                         : [NSMutableArray array];
    [tasks addObject: activeTask];
    self.activeTasks = tasks;
}


@end
