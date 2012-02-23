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


#define kProgressPollInterval 0.5


@interface CouchPersistentReplication ()
@property (readwrite) CouchReplicationState state;
@property (nonatomic, readwrite, retain) NSError* error;
@property (nonatomic, readwrite) CouchReplicationMode mode;
- (void) setStatusString: (NSString*)status;
@end


@implementation CouchPersistentReplication


@dynamic source, target, create_target, continuous, filter, query_params, doc_ids;
@synthesize state=_state, completed=_completed, total=_total, error=_error, mode=_mode;


+ (CouchPersistentReplication*) createWithReplicatorDatabase: (CouchDatabase*)replicatorDB
                                                      source: (NSString*)source
                                                      target: (NSString*)target
{
    CouchPersistentReplication* rep = [[self alloc] initWithNewDocumentInDatabase: replicatorDB];
    rep.autosaves = YES;
    [rep setValue: source ofProperty: @"source"];
    [rep setValue: target ofProperty: @"target"];
    return [rep autorelease];
}


- (void)dealloc {
    self.state = kReplicationIdle;  // turns off observing
    [_statusString release];
    [super dealloc];
}


- (void) actAsUser: (NSString*)username withRoles: (NSArray*)roles {
    // See https://gist.github.com/832610 (Section 8)
    NSMutableDictionary *userCtx = nil;
    if (username || roles) {
        userCtx = [NSMutableDictionary dictionary];
        [userCtx setValue: username forKey: @"name"];
        [userCtx setValue: roles forKey: @"roles"];
    }
    [self setValue: userCtx ofProperty: @"user_ctx"];
}

- (void) actAsAdmin {
    [self actAsUser: nil withRoles: [NSArray arrayWithObject: @"_admin"]];
}


- (NSURL*) remoteURL {
    NSString* urlStr = self.source;
    if ([urlStr rangeOfString: @":"].length == 0)
        urlStr = self.target;
    return [NSURL URLWithString: urlStr];
}


- (CouchReplicationState) state {
    return _state;
}


- (void) setState:(CouchReplicationState)state {
    // Add/remove myself as an observer of the server's activeTasks:
    CouchServer* server = self.database.server;
    if (state == kReplicationTriggered) {
        if (_state != kReplicationTriggered) {
            [server addObserver: self forKeyPath: @"activeTasks"
                        options:0 context: NULL];
        }
    } else {
        if (_state == kReplicationTriggered) {
            [server removeObserver: self forKeyPath: @"activeTasks"];
            [self setStatusString: nil];
        }
    }
    _state = state;
}


- (void) didLoadFromDocument {
    // Update state:
    static NSArray* kStateNames;
    if (!kStateNames)
        kStateNames = [[NSArray alloc] initWithObjects: @"", @"triggered", @"completed", @"error",
                       nil];
    NSString* stateStr = [self getValueOfProperty: @"_replication_state"];
    NSUInteger state = stateStr ? [kStateNames indexOfObject: stateStr] : NSNotFound;
    if (state == NSNotFound)
        state = kReplicationIdle;
    if (state != _state) {
        COUCHLOG(@"%@: state := %@", self, stateStr);
        self.state = (CouchReplicationState) state;
    }
}


- (RESTOperation*) deleteWithRetries: (int)retries {
    RESTOperation* op = [super deleteDocument];
    [op onCompletion:^{
        if (op.httpStatus == 409  && retries > 0) {
            COUCHLOG(@"%@: retrying DELETE (%i tries left)", self, retries);
            [self deleteWithRetries: retries - 1];
        } else if (op.error) {
            Warn(@"%@: DELETE failed, %@", self, op.error);
        }
    }];
    return op;
}


- (RESTOperation*) deleteDocument {
    self.state = kReplicationIdle;  // turns off observing

    // Replication documents are problematic to delete, because the CouchDB replicator process
    // updates them with status information. This can result in race conditions deleting them,
    // where the app sends a DELETE using the latest rev number it knows, before getting the
    // _changes-feed notification that the replicator has added a new revision.
    // Currently the only workaround is simply to retry when this happens.
    return [self deleteWithRetries: 10];
}


- (void) restartWithRetries: (int)retries {
    [self setValue: nil ofProperty: @"_replication_state"];
    RESTOperation* op = [self save];
    [op onCompletion:^{
        if (op.httpStatus == 409 && retries > 0) {
            COUCHLOG(@"%@: retrying restart (%i tries left)", self, retries);
            [self restartWithRetries: retries - 1];
        } else if (op.error) {
            Warn(@"%@: Restart failed, %@", self, op.error);
        }
    }];
}

- (void) restart {
    [self restartWithRetries: 10];
}


#pragma mark - STATUS TRACKING


- (void) setStatusString: (NSString*)status {
    COUCHLOG(@"%@ = %@", self, status);
    [_statusString autorelease];
    _statusString = [status copy];
    CouchReplicationMode mode = _mode;
    int completed = _completed, total = _total;
    
    if ([status isEqualToString: @"Stopped"]) {
        // TouchDB only
        mode = kCouchReplicationStopped;
        
    } else if ([status isEqualToString: @"Offline"]) {
        mode = kCouchReplicationOffline;
    } else if ([status isEqualToString: @"Idle"]) {
        mode = kCouchReplicationIdle;
        completed = total = 0;
    } else {
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
                Warn(@"CouchReplication: Unable to parse status string \"%@\"", _statusString);
            }
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
    if (mode != _mode)
        self.mode = mode;
}


- (void) observeValueForKeyPath: (NSString*)keyPath ofObject: (id)object 
                         change: (NSDictionary*)change context: (void*)context
{
    CouchServer* server = self.database.server;
    if ([keyPath isEqualToString: @"activeTasks"] && object == server) {
        // Server's activeTasks changed:
        NSString* myReplicationID = [self getValueOfProperty: @"_replication_id"];
        NSString* status = nil;
        NSArray* error = nil;
        for (NSDictionary* task in server.activeTasks) {
            if ([[task objectForKey:@"type"] isEqualToString:@"Replication"]) {
                // Can't look up the task ID directly because it's part of a longer string like
                // "`6390525ac52bd8b5437ab0a118993d0a+continuous`: ..."
                if ([[task objectForKey: @"task"] rangeOfString: myReplicationID].length > 0) {
                    status = [task objectForKey: @"status"];
                    error = $castIf(NSArray, [task objectForKey: @"error"]);
                    break;
                }
            }
        }

        // Interpret .error property. This is nonstandard; only TouchDB supports it.
        if (error.count >= 1) {
            COUCHLOG(@"%@: error %@", self, error);
            int status = [$castIf(NSNumber, [error objectAtIndex: 0]) intValue];
            NSString* message = nil;
            if (error.count >= 2)
                message = $castIf(NSString, [error objectAtIndex: 1]);
            self.error = [RESTOperation errorWithHTTPStatus: status message: message
                                                        URL: self.document.URL];
        }
        
        if (!$equal(status, _statusString))
            [self setStatusString: status];
    } else {
        [super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
    }
}


@end
