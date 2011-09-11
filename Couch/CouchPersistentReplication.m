//
//  CouchPersistentReplication.m
//  CouchCocoa
//
//  Created by Jens Alfke on 9/8/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

//  REFERENCES:
//  http://docs.couchbase.org/couchdb-release-1.1/index.html#couchb-release-1.1-replicatordb
//  https://gist.github.com/832610

#import "CouchPersistentReplication.h"
#import "CouchInternal.h"


@interface CouchPersistentReplication ()
@property (readwrite) CouchReplicationState state;
@end


@implementation CouchPersistentReplication


@dynamic source, target, create_target, continuous;
@synthesize state=_state, completed=_completed, total=_total;


+ (CouchPersistentReplication*) createWithReplicatorDatabase: (CouchDatabase*)replicatorDB
                                                      source: (NSString*)source
                                                      target: (NSString*)target
{
    CouchPersistentReplication* rep = [[self alloc] initWithNewDocumentInDatabase: replicatorDB];
    rep.autosaves = YES;
    [rep setValue: source ofProperty: @"source"];
    [rep setValue: target ofProperty: @"target"];
    return rep;
}


- (void) didLoadFromDocument {
    // Update state:
    CouchReplicationState state = kReplicationIdle;
    NSString* stateStr = [self getValueOfProperty: @"_replication_state"];
    if ([stateStr isEqualToString: @"triggered"])
        state = kReplicationTriggered;
    else if ([stateStr isEqualToString: @"completed"])
        state = kReplicationCompleted;
    else if ([stateStr isEqualToString: @"error"])
        state = kReplicationError;
    if (state != _state) {
        COUCHLOG(@"Replication: state=%@", stateStr);
        self.state = state;
    }
    //TODO: Update completed, total
}


- (RESTOperation*) deleteWithRetries: (int)retries {
    RESTOperation* op = [super deleteDocument];
    [op onCompletion:^{
        if (op.httpStatus == 409  && retries > 0) {
            COUCHLOG(@"CouchPersistentReplication: retrying DELETE (%i tries left)", retries);
            [self deleteWithRetries: retries - 1];
        }
    }];
    return op;
}


- (RESTOperation*) deleteDocument {
    // Replication documents are problematic to delete, because the CouchDB replicator process
    // updates them with status information. This can result in race conditions deleting them,
    // where the app sends a DELETE using the latest rev number it knows, before getting the
    // _changes-feed notification that the replicator has added a new revision.
    // Currently the only workaround is simply to retry when this happens.
    return [self deleteWithRetries: 10];
}


@end
