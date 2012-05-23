//
//  CouchPersistentReplication.h
//  CouchCocoa
//
//  Created by Jens Alfke on 9/8/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchModel.h"
#import "CouchReplication.h"


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
    NSError* _error;
    CouchReplicationMode _mode;
}

/** The local database being replicated to/from. */
@property (readonly) CouchDatabase* localDatabase;

/** The remote database being replicated to/from. */
@property (readonly) NSURL* remoteURL;

/** Does the replication pull from (as opposed to push to) the target? */
@property (nonatomic, readonly) bool pull;

/** Should the target database be created if it doesn't already exist? (Defaults to NO). */
@property bool create_target;

/** Should the replication operate continuously, copying changes as soon as the source database is modified? (Defaults to NO). */
@property bool continuous;

/** Path of an optional filter function to run on the source server.
    Only documents for which the function returns true are sent to the destination.
    The path looks like "designdocname/filtername". */
@property (copy) NSString* filter;

/** Parameters to pass to the filter function.
    Should be a JSON-compatible dictionary. */
@property (copy) NSDictionary* query_params;

/** Sets the documents to specify as part of the replication. */
@property (copy) NSArray *doc_ids;

/** Extra HTTP headers to send in all requests to the remote server.
    Should map strings (header names) to strings. */
@property (copy) NSDictionary* headers;

/** OAuth parameters that the replicator should use when authenticating to the remote database.
    Keys in the dictionary should be "consumer_key", "consumer_secret", "token", "token_secret", and optionally "signature_method". */
@property (nonatomic, copy) NSDictionary* OAuth;

/** Sets the "user_ctx" property of the replication, which identifies what privileges it will run with when accessing the local server. To replicate design documents, this should be set to a value with "_admin" in the list of roles.
    The server will not let you specify privileges you don't have, so the request to create the replication must be made with credentials that match what you're setting here, unless the server is in no-authentication "admin party" mode.
    See <https://gist.github.com/832610>, section 8, for details.
    If both 'user' and 'roles' are nil, the user_ctx will be cleared.
    @param username  A server username, or nil
    @param roles  An array of CouchDB role name strings, or nil */
- (void) actAsUser: (NSString*)username withRoles: (NSArray*)roles;

/** A convenience that calls -actAsUser:withRoles: to specify the _admin role. */
- (void) actAsAdmin;

/** Restarts a replication; this is most useful to make a non-continuous replication run again after it's stopped. */
- (void) restart;

/** The current state of replication activity. */
@property (readonly) CouchReplicationState state;

/** The number of completed changes processed, if the task is active, else 0 (observable). */
@property (nonatomic, readonly) unsigned completed;

/** The total number of changes to be processed, if the task is active, else 0 (observable). */
@property (nonatomic, readonly) unsigned total;

@property (nonatomic, readonly, retain) NSError* error;

@property (nonatomic, readonly) CouchReplicationMode mode;

@end
