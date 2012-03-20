//
//  CouchTouchDBServer.h
//  CouchCocoa
//
//  Created by Jens Alfke on 12/20/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchServer.h"
@class TDServer, TDDatabase;


/** A convenience class that glues TouchDB into CouchCocoa.
    On creation, starts up an instance of TDServer and sets up TDURLProtocol to serve it.
    The CouchServer URL is set to the root URL served by the protocol, so you can treat it just like a normal remote server instance. */
@interface CouchTouchDBServer : CouchServer
{
    @private
    TDServer* _touchServer;
    NSError* _error;
    BOOL _observing;
}

/** A shared per-process instance. Remember that CouchCocoa is not thread-safe so you can't
 use this shared instance among multiple threads. */
+ (CouchTouchDBServer*) sharedInstance;

/** Preferred initializer. Starts up an in-process server. */
- (id)init;

/** Inherited initializer, if you want to connect to a remote server for debugging purposes. */
- (id) initWithURL: (NSURL*)url;

/** If this is non-nil, the server failed to initialize. */
@property (readonly) NSError* error;

/** Invokes the given block on the TouchDB server thread, passing it a pointer to the TDServer.
    You can use this to (carefully!) access the TDServer API.
    Be aware that the block may not run immediately; it's queued and will be called immediately before the server handles the next REST call. */
- (void) tellTDServer: (void (^)(TDServer*))block;

/** Invokes the given block on the TouchDB server thread, passing it a pointer to a TDDatabase.
    You can use this to (carefully!) access the TDDatabase API.
    Be aware that the block may not run immediately; it's queued and will be called immediately before the server handles the next REST call. */
- (void) tellTDDatabaseNamed: (NSString*)dbName to: (void (^)(TDDatabase*))block;

@end
