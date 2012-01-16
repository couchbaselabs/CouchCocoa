//
//  CouchReplication.h
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

#import <Foundation/Foundation.h>
@class CouchDatabase, RESTOperation;


/** Option flags for replication (push/pull). */
enum {
    kCouchReplicationCreateTarget = 1,  /**< Create the destination database if it doesn't exist */
    kCouchReplicationContinuous   = 2,  /**< Continuous mode; remains active till canceled */
};
typedef NSUInteger CouchReplicationOptions;


/** Tracks a CouchDB replication. Can be used to observe its progress. */
@interface CouchReplication : NSObject
{
    CouchDatabase* _database;
    NSURL* _remote;
    BOOL _pull;
    CouchReplicationOptions _options;
    BOOL _running;
    NSString* _taskID;
    NSString* _status;
    unsigned _completed, _total;
    NSError* _error;
}

/** Starts the replication, asynchronously.
    @return  The operation to start replication, or nil if replication is already started. */
- (RESTOperation*) start;

/** Stops replication, asynchronously. */
- (void) stop;

@property (nonatomic, readonly) NSURL* remoteURL;

@property (nonatomic, readonly) BOOL running;

/** The current status string from the server, if active, else nil (observable).
    Usually of the form "Processed 123 / 123 changes". */
@property (nonatomic, readonly, copy) NSString* status;

/** The number of completed changes processed, if the task is active, else 0 (observable). */
@property (nonatomic, readonly) unsigned completed;

/** The total number of changes to be processed, if the task is active, else 0 (observable). */
@property (nonatomic, readonly) unsigned total;

@property (nonatomic, readonly, retain) NSError* error;

@end
