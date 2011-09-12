//
//  CouchPersistentReplication.h
//  CouchCocoa
//
//  Created by Jens Alfke on 9/8/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchModel.h"


/** Possible current states of a replication. */
typedef enum {
    kReplicationIdle,           /**< No current replication activity. */
    kReplicationTriggered,      /**< Replication in progress. */
    kReplicationCompleted,      /**< Replication finished successfully. */
    kReplicationError           /**< Replication failed with an error. */
} CouchReplicationState;


/** A model object representing a persistent replication to or from another database.
    Each instance represents a document in the server's special _replication database.
    Instances are created by the -replicate... factory methods on CouchDatabase. */
@interface CouchPersistentReplication : CouchModel
{
    @private
    CouchReplicationState _state;
    unsigned _completed, _total;
    NSString* _statusString;
}

/** The source URL for the replication.
    This will be either a complete HTTP(s) URL or the name of a database on this server. */
@property (readonly, copy) NSString* source;

/** The destination URL for the replication.
    This will be either a complete HTTP(s) URL or the name of a database on this server. */
@property (readonly, copy) NSString* target;

/** Should the target database be created if it doesn't already exist? (Defaults to NO). */
@property bool create_target;

/** Should the replication operate continuously, copying changes as soon as the source database is modified? (Defaults to NO). */
@property bool continuous;

/** The current state of replication activity. */
@property (readonly) CouchReplicationState state;

/** The number of completed changes processed, if the task is active, else 0 (observable). */
@property (nonatomic, readonly) unsigned completed;

/** The total number of changes to be processed, if the task is active, else 0 (observable). */
@property (nonatomic, readonly) unsigned total;

@end
