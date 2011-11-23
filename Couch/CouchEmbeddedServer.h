//
//  CouchEmbeddedServer.h
//  CouchCocoa
//
//  Created by Jens Alfke on 10/13/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchServer.h"
@class CouchbaseMobile;

/** A convenience class that glues Couchbase Mobile into CouchCocoa.
    On creation, starts up an instance of Couchbase (or CouchbaseMobile).
    This object will have a placeholder URL until the embedded server has started up, so you can't access it (i.e. creating any databases) until then. */
@interface CouchEmbeddedServer : CouchServer
{
    @private
    CouchbaseMobile* _couchbase;
    NSError* _error;
    void(^_onStartBlock)();
}

/** A shared per-process instance. Remember that CouchCocoa is not thread-safe so you can't
    use this shared instance among multiple threads. */
+ (CouchEmbeddedServer*) sharedInstance;

/** Preferred initializer. Starts up an in-process server. */
- (id) init;

/** Inherited initializer, if you want to connect to a remote server for debugging purposes.
    (If you call -start:, the block will still be called.) */
- (id) initWithURL:(NSURL *)url;

/** The underlying CouchbaseMobile object that manages the embedded server. */
@property (readonly) CouchbaseMobile* couchbase;

/** Starts the server, asynchronously.
    @param onStartBlock  A block to be called when the server finishes starting up (or fails to). At that point you can start to access databases, etc.
    @return  YES if startup began, NO if a fatal error occurred. */
- (BOOL) start: (void(^)())onStartBlock;

/** Is the embedded Couchbase server running? */
@property (readonly) BOOL running;

/** If the server fails to start up, this will give the reason why. */
@property (readonly, retain) NSError* error;

@end


extern NSString* const CouchEmbeddedServerDidStartNotification;
extern NSString* const CouchEmbeddedServerDidRestartNotification;
