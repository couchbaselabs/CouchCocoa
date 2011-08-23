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
//
//  http://wiki.apache.org/couchdb/Replication
//

#import "CouchReplication.h"
#import "CouchInternal.h"


// Rate at which to poll the server activity feed to check for replication progress
#define kProgressPollInterval 1.0


@interface CouchReplication ()
@property (nonatomic, readwrite, copy) NSString* status;
@property (nonatomic, readwrite) unsigned completed, total;
@end


@implementation CouchReplication


- (id) initWithDatabase: (CouchDatabase*)database
                 remote: (NSURL*)remote
                   pull: (BOOL)pull
                options: (CouchReplicationOptions)options
{
    self = [super init];
    if (self) {
        _database = [database retain];
        _remote = [remote retain];
        _pull = pull;
        _options = options;

    }
    return self;
}


- (void)dealloc {
    [self stop];
    [_remote release];
    [_database release];
    [super dealloc];
}


- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@ %@]",
                self.class, (_pull ? @"from" : @"to"), _remote];
}


- (RESTOperation*) operationToStart: (BOOL)start {
    NSString* source = _pull ? _remote.absoluteString : _database.relativePath;
    NSString* target = _pull ? _database.relativePath : _remote.absoluteString;
    NSMutableDictionary* body = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 source, @"source",
                                 target, @"target",
                                 nil];
    if (_options & kCouchReplicationCreateTarget)
        [body setObject: (id)kCFBooleanTrue forKey: @"create_target"];
    if (_options & kCouchReplicationContinuous)
        [body setObject: (id)kCFBooleanTrue forKey: @"continuous"];
    if (!start)
        [body setObject: (id)kCFBooleanTrue forKey: @"cancel"];
    RESTResource* replicate = [[[RESTResource alloc] initWithParent: _database.server 
                                                       relativePath: @"_replicate"] autorelease];
    return [replicate POSTJSON: body parameters: nil];
}


- (RESTOperation*) start {
    if (_started)
        return nil;
    _started = YES;
    RESTOperation* op = [self operationToStart: YES];
    [op onCompletion: ^{
        NSDictionary* response = op.responseBody.fromJSON;
        if (op.isSuccessful) {
            _taskID = [[response objectForKey: @"_local_id"] copy];
            if (_taskID) {
                // Successfully started:
                _database.server.activityPollInterval = kProgressPollInterval;
                [_database.server addObserver: self forKeyPath: @"activeTasks"
                                      options:0 context: NULL];
            }
        }
        if (!_taskID) {
            Warn(@"Couldn't start %@: %@", self, op.error);
            _started = NO;
        }
    }];
    return op;
}


- (void) stop {
    if (_started) {
        [[self operationToStart: NO] start];
        self.status = nil;
        if (_taskID) {
            [_taskID release];
            _taskID = nil;
            [_database.server removeObserver: self forKeyPath: @"activeTasks"];
        }
    }
}


@synthesize status=_status, completed=_completed, total=_total;


- (NSString*) status {
    return _status;
}

- (void) setStatus: (NSString*)status {
    COUCHLOG(@"%@ = %@", self, status);
    [_status autorelease];
    _status = [status copy];
    
    int completed = 0, total = 0;
    if (status) {
        // Current format of status is "Processed \d+ / \d+ changes".
        NSScanner* scanner = [NSScanner scannerWithString: status];
        if ([scanner scanString: @"Processed" intoString:NULL]
                && [scanner scanInt: &completed]
                && [scanner scanString: @"/" intoString:NULL]
                && [scanner scanInt: &total]
                && [scanner scanString: @"changes" intoString:NULL]) {
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


- (void) observeValueForKeyPath: (NSString*)keyPath ofObject: (id)object 
                         change: (NSDictionary*)change context: (void*)context
{
    // Server's activeTasks changed:
    NSString* status = nil;
    for (NSDictionary* task in _database.server.activeTasks) {
        if ([[task objectForKey:@"type"] isEqualToString:@"Replication"]) {
            // Can't look up the task ID directly because it's part of a longer string like
            // "`6390525ac52bd8b5437ab0a118993d0a+continuous`: ..."
            if ([[task objectForKey: @"task"] rangeOfString: _taskID].length > 0) {
                status = [task objectForKey: @"status"];
                break;
            }
        }
    }
    if (!$equal(status, _status))
        self.status = status;
}


@end
