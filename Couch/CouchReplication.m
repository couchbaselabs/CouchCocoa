//
//  CouchReplication.m
//  CouchCocoa
//
//  Created by Jens Alfke on 8/15/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

//  REFERENCES:
//  http://wiki.apache.org/couchdb/Replication

#import "CouchReplication.h"
#import "CouchInternal.h"


// Rate at which to poll the server activity feed to check for replication progress
#define kProgressPollInterval 1.0


@interface CouchReplication ()
@property (nonatomic, readwrite) BOOL running;
@property (nonatomic, readwrite, copy) NSString* status;
@property (nonatomic, readwrite) unsigned completed, total;
@property (nonatomic, readwrite, retain) NSError* error;
@property (nonatomic, readwrite) CouchReplicationMode mode;
- (void) stopped;
@end


@implementation CouchReplication


- (id) initWithDatabase: (CouchDatabase*)database
                 remote: (NSURL*)remote
{
    NSParameterAssert(remote);
    self = [super init];
    if (self) {
        _database = [database retain];
        _remote = [remote retain];
        // Give the caller a chance to customize parameters like .filter before calling -start,
        // but make sure -start will be run even if the caller doesn't call it.
        [self performSelector: @selector(start) withObject: nil afterDelay: 0.0];
    }
    return self;
}


- (void)dealloc {
    COUCHLOG2(@"%@: dealloc", self);
    [_remote release];
    [_database release];
    [_status release];
    [_error release];
    [_filter release];
    [_filterParams release];
    [_options release];
    [_headers release];
    [_oauth release];
    [super dealloc];
}


- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@ %@]",
                self.class, (_pull ? @"from" : @"to"), _remote];
}


@synthesize pull=_pull, createTarget=_createTarget, continuous=_continuous,
            filter=_filter, filterParams=_filterParams, options=_options, headers=_headers,
            OAuth=_oauth, localDatabase=_database;


- (RESTOperation*) operationToStart: (BOOL)start {
    id source = _pull ? _remote.absoluteString : _database.relativePath;
    id target = _pull ? _database.relativePath : _remote.absoluteString;
    if (_headers.count > 0 || _oauth != nil) {
        // Convert 'source' or 'target' to a dictionary so we can add metadata to it:
        id *param = _pull ? &source : &target;
        *param = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                  *param, @"url",
                  _headers, @"headers",
                  nil];
        if (_oauth) {
            NSDictionary* auth = [NSDictionary dictionaryWithObject: _oauth forKey: @"oauth"];
            [*param setObject: auth forKey: @"auth"];
        }
    }
    NSMutableDictionary* body = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 source, @"source",
                                 target, @"target",
                                 nil];
    if (_createTarget)
        [body setObject: (id)kCFBooleanTrue forKey: @"create_target"];
    if (_continuous)
        [body setObject: (id)kCFBooleanTrue forKey: @"continuous"];
    if (_filter) {
        [body setObject: _filter forKey: @"filter"];
        if (_filterParams)
            [body setObject: _filterParams forKey: @"query_params"];
    }
    if (_options)
        [body addEntriesFromDictionary: _options];

    if (!start)
        [body setObject: (id)kCFBooleanTrue forKey: @"cancel"];
    RESTResource* replicate = [[[RESTResource alloc] initWithParent: _database.server 
                                                       relativePath: @"_replicate"] autorelease];
    return [replicate POSTJSON: body parameters: nil];
}


- (RESTOperation*) start {
    [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(start) object: nil];
    if (_running)
        return nil;
    self.error = nil;
    self.running = YES;
    RESTOperation* op = [self operationToStart: YES];
    [op onCompletion: ^{
        if (!_running)
            return;  // already stopped
        NSDictionary* response = op.responseBody.fromJSON;
        if (!op.isSuccessful) {
            Warn(@"%@ couldn't start: %@", self, op.error);
            self.error = op.error;
            self.running = NO;
        } else if ([response objectForKey: @"no_changes"]) {
            // Nothing to replicate:
            COUCHLOG(@"%@: no_changes", self);
            self.running = NO;
        } else {
            // Get the activity/task ID from the response:
            _taskID = [[response objectForKey: @"session_id"] copy];     // CouchDB 1.2+
            if (!_taskID)
                _taskID = [[response objectForKey: @"_local_id"] copy];  // Earlier versions
            
            if (_taskID) {
                // Successfully started:
                COUCHLOG(@"%@: task ID = '%@'", self, _taskID);
                [self retain];  // so I don't go away while active; see [self release] in -stopped
                [_database.server registerActiveTask: [NSDictionary dictionaryWithObjectsAndKeys:
                                                       @"Replication", @"type",
                                                       _taskID, @"task", nil]];
                [_database.server addObserver: self forKeyPath: @"activeTasks"
                                      options: 0 context: NULL];
            } else  {
                // Huh, something's wrong.
                Warn(@"%@ couldn't find _local_id in response: %@", self, response);
                self.running = NO;
                self.error = [RESTOperation errorWithHTTPStatus: 599 message: nil URL: _remote]; // TODO: Real err
            }
        }
    }];
    return op;
}


- (void) stopped {
    self.status = nil;
    if (_taskID) {
        [_taskID release];
        _taskID = nil;
        [_database.server removeObserver: self forKeyPath: @"activeTasks"];
        [self autorelease]; // balances [self retain] when successfully started
    }
    self.running = NO;
    self.mode = kCouchReplicationStopped;
}


- (void) stop {
    if (_running) {
        [[self operationToStart: NO] start];
        [self stopped];
    }
}


@synthesize running = _running, status=_status, completed=_completed, total=_total, error = _error;
@synthesize mode=_mode, remoteURL = _remote;


- (NSString*) status {
    return _status;
}

- (void) setStatus: (NSString*)status {
    COUCHLOG(@"%@ status line = %@", self, status);
    [_status autorelease];
    _status = [status copy];
    CouchReplicationMode mode = _mode;
    
    if ([status isEqualToString: @"Stopped"]) {
        // TouchDB only
        COUCHLOG(@"%@: Status changed to 'Stopped'", self);
        [self stopped];
        mode = kCouchReplicationStopped;
        
    } else if ([status isEqualToString: @"Offline"]) {
        mode = kCouchReplicationOffline;
    } else if ([status isEqualToString: @"Idle"]) {
        mode = kCouchReplicationIdle;
    } else {
        int completed = 0, total = 0;
        if (status) {
            // Current format of status is "Processed \d+ / \d+ changes".
            NSScanner* scanner = [NSScanner scannerWithString: status];
            if ([scanner scanString: @"Processed" intoString:NULL]
                    && [scanner scanInt: &completed]
                    && [scanner scanString: @"/" intoString:NULL]
                    && [scanner scanInt: &total]
                    && [scanner scanString: @"changes" intoString:NULL]) {
                mode = kCouchReplicationActive;
            } else {
                completed = total = 0;
                Warn(@"CouchReplication: Unable to parse status string \"%@\"", _status);
            }
        }
        
        if (completed != _completed || total != _total) {
            [self willChangeValueForKey: @"completed"];
            [self willChangeValueForKey: @"total"];
            _completed = completed;
            _total = total;
            [self didChangeValueForKey: @"total"];
            [self didChangeValueForKey: @"completed"];
        }
    }

    if (mode != _mode)
        self.mode = mode;
}


- (void) observeValueForKeyPath: (NSString*)keyPath ofObject: (id)object 
                         change: (NSDictionary*)change context: (void*)context
{
    // Server's activeTasks changed:
    BOOL active = NO;
    NSString* status = nil;
    NSArray* error = nil;
    for (NSDictionary* task in _database.server.activeTasks) {
        if ([[task objectForKey:@"type"] isEqualToString:@"Replication"]) {
            // Can't look up the task ID directly because it's part of a longer string like
            // "`6390525ac52bd8b5437ab0a118993d0a+continuous`: ..."
            if ([[task objectForKey: @"task"] rangeOfString: _taskID].length > 0) {
                active = YES;
                status = $castIf(NSString, [task objectForKey: @"status"]);
                error = $castIf(NSArray, [task objectForKey: @"error"]);
                break;
            }
        }
    }
    
    if (!active) {
        COUCHLOG(@"%@: No longer an active task", self);
        [self stopped];
        return;
    }
    
    // Interpret .error property. This is nonstandard; only TouchDB supports it.
    if (error.count >= 1) {
        COUCHLOG(@"%@: error %@", self, error);
        int status = [$castIf(NSNumber, [error objectAtIndex: 0]) intValue];
        NSString* message = nil;
        if (error.count >= 2)
            message = $castIf(NSString, [error objectAtIndex: 1]);
        self.error = [RESTOperation errorWithHTTPStatus: status message: message URL: _remote];
    }
    
    if (!$equal(status, _status)) {
        self.status = status;
    }
}


@end
