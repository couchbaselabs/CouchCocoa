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


// Declare essential bits of TD_Server and TDURLProtocol to avoid having to #import TouchDB:
@interface TD_Server : NSObject
- (id) initWithDirectory: (NSString*)dirPath
                   error: (NSError**)outError;
- (id) initWithDirectory: (NSString*)dirPath
                 options: (const struct TD_DatabaseManagerOptions*)options
                   error: (NSError**)outError;
- (void) queue: (void(^)())block;
- (void) tellDatabaseNamed: (NSString*)dbName to: (void (^)(TD_Database*))block;
- (void) close;
@end

@interface TDURLProtocol : NSURLProtocol
+ (NSURL*) rootURL;
+ (void) setServer: (TD_Server*)server;
+ (NSURL*) registerServer: (TD_Server*)server;
@end

@interface TDReplicator
+ (NSString *)progressChangedNotification;
+ (NSString *)stoppedNotification;
@end


@implementation CouchTouchDBServer


+ (CouchTouchDBServer*) sharedInstance {
    static CouchTouchDBServer* sInstance;
    static NSThread* sThread;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sInstance = [[self alloc] init];
        sThread = [NSThread currentThread];
    });
    NSAssert([NSThread currentThread] == sThread,
             @"Don't use CouchTouchDBServer sharedInstance on multiple threads");
    return sInstance;
}


- (id)init {
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                         NSUserDomainMask, YES);
    NSString* path = [paths objectAtIndex:0];
#if !TARGET_OS_IPHONE
    path = [path stringByAppendingPathComponent: [[NSBundle mainBundle] bundleIdentifier]];
#endif
    path = [path stringByAppendingPathComponent: @"TouchDB"];

    [[NSFileManager defaultManager] createDirectoryAtPath: path
                              withIntermediateDirectories: YES
                                               attributes: nil error: NULL];

    return [self initWithServerPath: path options: NULL];
}


- (id) initWithServerPath: (NSString*)serverPath
                  options: (const struct TD_DatabaseManagerOptions*)options
{
    // On Mac OS TouchDB.framework is linked dynamically, so avoid explicit references to its
    // classes because they'd create link errors building CouchCocoa.
    Class classTDURLProtocol = NSClassFromString(@"TDURLProtocol");
    Class classTDServer = NSClassFromString(@"TD_Server");
    NSAssert(classTDURLProtocol && classTDServer,
             @"Not linked with TouchDB framework (or you didn't use the -ObjC linker flag)");
    
    COUCHLOG(@"Creating CouchTouchDBServer at %@", serverPath);
    NSError* error;
    TD_Server* server;
    if ([classTDServer instancesRespondToSelector: @selector(initWithDirectory:options:error:)]) {
        server = [[classTDServer alloc] initWithDirectory: serverPath
                                                  options: options
                                                    error: &error];
    } else {
        NSAssert(!options, @"TD_Server initializer with options is unavailable in TouchDB");
        server = [[classTDServer alloc] initWithDirectory: serverPath
                                                    error: &error];
    }
    NSURL* rootURL = server ? [classTDURLProtocol registerServer: server]
                            : [classTDURLProtocol rootURL];
    
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

- (id) initWithServerPath: (NSString*)serverPath {
    return [self initWithServerPath: serverPath options: NULL];
}


- (id) initWithURL:(NSURL *)url {
    if (url)
        return [super initWithURL: url];
    else
        return [self init];
}


- (id) copyWithZone: (NSZone*)zone {
    CouchTouchDBServer* copied = [[[self class] alloc] initWithURL: self.URL];
    if (copied)
        copied->_touchServer = _touchServer;
    return copied;
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


- (void) tellTDServer: (void (^)(TD_Server*))block {
    TD_Server* server = _touchServer;
    [_touchServer queue: ^{ block(server); }];
}


- (void) tellTDDatabaseNamed: (NSString*)dbName to: (void (^)(TD_Database*))block {
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

    // Look up the notification names (since I am not linked against TouchDB):
    Class classTDReplicator = NSClassFromString(@"TDReplicator");
    NSAssert(classTDReplicator, @"Couldn't find class TDReplicator");
    NSString* replProgressChangedNotification = [classTDReplicator progressChangedNotification];
    NSString* replStoppedNotification = [classTDReplicator stoppedNotification];

    if (observe) {
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(replicationProgressChanged:)
                                                     name: replProgressChangedNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(replicationProgressChanged:)
                                                     name: replStoppedNotification
                                                   object: nil];
        [self performSelector: @selector(checkActiveTasks) withObject: nil afterDelay: 0.0];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:replProgressChangedNotification
                                                      object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:replStoppedNotification
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
