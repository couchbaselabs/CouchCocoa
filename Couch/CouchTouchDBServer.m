//
//  CouchTouchDBServer.m
//  CouchCocoa
//
//  Created by Jens Alfke on 12/20/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchTouchDBServer.h"
#import "CouchTouchDBDatabase.h"
#import "CouchInternal.h"

#import "TDServer.h"
#import "TDURLProtocol.h"
#import "TDReplicator.h"


@implementation CouchTouchDBServer


+ (CouchTouchDBServer*) sharedInstance {
    static CouchTouchDBServer* sInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sInstance = [[self alloc] init];
    });
    return sInstance;
}


- (id)init {
    self = [super initWithURL: [TDURLProtocol rootURL]];
    if (self) {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                             NSUserDomainMask, YES);
        NSString* path = [paths objectAtIndex:0];
#if !TARGET_OS_IPHONE
        path = [path stringByAppendingPathComponent: [[NSBundle mainBundle] bundleIdentifier]];
#endif
        path = [path stringByAppendingPathComponent: @"TouchDB"];
        COUCHLOG(@"Creating CouchTouchDBServer at %@", path);
        NSError* error = nil;
        if ([[NSFileManager defaultManager] createDirectoryAtPath: path
                                      withIntermediateDirectories: YES
                                                       attributes: nil error: &error]) {
            _touchServer = [[TDServer alloc] initWithDirectory: path error: &error];
        }
        if (_touchServer)
            [TDURLProtocol setServer: _touchServer];
        else
            _error = [error retain];
    }
    return self;
}


- (id) initWithServerPath: (NSString*)serverPath {
    NSError* error;
    TDServer* server = [[TDServer alloc] initWithDirectory: serverPath error: &error];
    NSURL* rootURL = server ? [TDURLProtocol registerServer: server] : [TDURLProtocol rootURL];
    
    self = [super initWithURL: rootURL];
    if (self) {
        _touchServer = server;
        if (!server)
            _error = [error retain];
    } else {
        [server release];
    }
    return self;
}


- (id) initWithURL:(NSURL *)url {
    if (url)
        return [super initWithURL: url];
    else
        return [self init];
}


- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self close];
    [_error release];
    [super dealloc];
}


@synthesize error=_error;


- (Class) databaseClass {
    return [CouchTouchDBDatabase class];
}


- (void) tellTDServer: (void (^)(TDServer*))block {
    TDServer* server = _touchServer;
    [_touchServer queue: ^{ block(server); }];
}


- (void) tellTDDatabaseNamed: (NSString*)dbName to: (void (^)(TDDatabase*))block {
    [_touchServer tellDatabaseNamed: dbName to: block];
}


- (void) close {
    [super close];
    [_touchServer close];
    [_touchServer release];
    _touchServer = nil;
}


#pragma mark - ACTIVITY:

// I don't have to resort to polling the /_activity URL; I can listen for direct notifications
// from TDReplication.

- (void) setActivityPollInterval: (NSTimeInterval)interval {
    BOOL observe = (interval > 0.0);
    if (observe == _observing)
        return;
    if (observe) {
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(replicationProgressChanged:)
                                                     name: TDReplicatorProgressChangedNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(replicationProgressChanged:)
                                                     name: TDReplicatorStoppedNotification
                                                   object: nil];
        [self performSelector: @selector(checkActiveTasks) withObject: nil afterDelay: 0.0];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:TDReplicatorProgressChangedNotification
                                                      object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:TDReplicatorStoppedNotification
                                                      object:nil];
    }
    _observing = observe;
}

- (NSTimeInterval) activityPollInterval {
    return _observing ? 1.0 : 0.0;
}


- (void) replicationProgressChanged: (NSNotification*)n {
    COUCHLOG(@"%@: Replication progress changed", self);//TEMP
    // This is called on the background TouchDB thread, so dispatch to main thread
    [self performSelectorOnMainThread: @selector(checkActiveTasks) withObject: nil
                        waitUntilDone: NO];
}




@end
