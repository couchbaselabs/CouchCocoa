//
//  CouchTouchDBServer.m
//  CouchCocoa
//
//  Created by Jens Alfke on 12/20/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchTouchDBServer.h"
#import "CouchInternal.h"


#if TARGET_OS_IPHONE
extern NSString* const TDReplicatorProgressChangedNotification;
extern NSString* const TDReplicatorStoppedNotification;
#else
// Copied from TouchDB's TDReplicator.m.
static NSString* TDReplicatorProgressChangedNotification = @"TDReplicatorProgressChanged";
static NSString* TDReplicatorStoppedNotification = @"TDReplicatorStopped";
#endif


// Declare essential bits of TDServer and TDURLProtocol to avoid having to #import TouchDB:
@interface TDServer : NSObject
- (id) initWithDirectory: (NSString*)dirPath error: (NSError**)outError;
@end

@interface TDURLProtocol : NSURLProtocol
+ (NSURL*) rootURL;
+ (void) setServer: (TDServer*)server;
@end



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
#if TARGET_OS_IPHONE
    Class classTDURLProtocol = [TDURLProtocol class];
    Class classTDServer = [TDServer class];
#else
    // On Mac OS TouchDB.framework is linked dynamically, so avoid explicit references to its
    // classes because they'd create link errors building CouchCocoa.
    Class classTDURLProtocol = NSClassFromString(@"TDURLProtocol");
    Class classTDServer = NSClassFromString(@"TDServer");
    NSAssert(classTDURLProtocol && classTDServer, @"Not linked with TouchDB framework");
#endif
        
    self = [super initWithURL: [classTDURLProtocol rootURL]];
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
            _touchServer = [[classTDServer alloc] initWithDirectory: path error: &error];
        }
        if (_touchServer)
            [classTDURLProtocol setServer: _touchServer];
        else
            _error = [error retain];
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
    [_touchServer release];
    [_error release];
    [super dealloc];
}


@synthesize touchServer=_touchServer, error=_error;


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
