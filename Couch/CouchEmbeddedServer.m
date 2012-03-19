//
//  CouchEmbeddedServer.m
//  CouchCocoa
//
//  Created by Jens Alfke on 10/13/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchEmbeddedServer.h"
#import "CouchInternal.h"
#import "CouchbaseMobile.h"     // Local copy of public header from Couchbase framework

#if TARGET_OS_IPHONE
#import <UIKit/UIApplication.h>
#else
// Note: Mac support for this is of practical use only with the experimental Mac branch of CBM.
#import <AppKit/NSApplication.h>
#endif


NSString* const CouchEmbeddedServerDidStartNotification = @"CouchEmbeddedServerDidRestart";
NSString* const CouchEmbeddedServerDidRestartNotification = @"CouchEmbeddedServerDidRestart";


@interface CouchEmbeddedServer () <CouchbaseDelegate>
@property (readwrite, retain) NSError* error;
@end


@implementation CouchEmbeddedServer


+ (CouchEmbeddedServer*) sharedInstance {
    static CouchEmbeddedServer* sInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sInstance = [[self alloc] init];
    });
    return sInstance;
}


- (id)init {
    // We don't know the real port that the server will be assigned, so default to 0 for now.
    self = [super initWithURL: [NSURL URLWithString: @"http://127.0.0.1:0"]];
    if (self) {
        // Look up class at runtime to avoid dependency on Couchbase.framework:
        Class couchbaseClass = NSClassFromString(@"Couchbase");
        NSAssert(couchbaseClass!=nil, @"Not linked with Couchbase framework");
        _couchbase = [[couchbaseClass alloc] init];
        _couchbase.delegate = self;
    }
    return self;
}


- (id) initWithURL:(NSURL *)url  {
    if (url)
        return [super initWithURL: url];
    else
        return [self init];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [_error release];
    [_onStartBlock release];
    [super dealloc];
}


@synthesize couchbase = _couchbase;


- (NSURL*)URL {
    NSURL* url = [super URL];
    NSAssert(url.port != 0, @"Can't use CouchEmbeddedServer till it's started up");
    return url;
}


- (BOOL) start: (void(^)())onStartBlock {
    BOOL ok;
    BOOL callItNow = NO;
    _onStartBlock = [onStartBlock copy];
    if (_couchbase) {
        ok = [_couchbase start];
        callItNow = !ok;
        self.error = _couchbase.error;
    } else {
        ok = YES;
        callItNow = YES;
    }
    if (callItNow)
        [self performSelector: @selector(callOnStart) withObject: nil afterDelay: 0.0];
    return ok;
}

- (void) callOnStart {
    _onStartBlock();
}


-(void)couchbaseMobile:(CouchbaseMobile*)couchbase didStart:(NSURL*)serverURL {
    COUCHLOG(@"CouchEmbeddedServer: Server started at <%@>", serverURL.absoluteString);
    BOOL firstStart = ([[[super URL] port] intValue] == 0);
    
    [self setURL: serverURL];

    NSNotificationCenter* nctr = [NSNotificationCenter defaultCenter];
    NSString* notificationToPost;
    if (firstStart) {
        if ([couchbase respondsToSelector: @selector(adminCredential)])
            [self setCredential: couchbase.adminCredential];
        self.tracksActiveOperations = YES;
#if TARGET_OS_IPHONE
        UIApplication* app = [UIApplication sharedApplication];
        [nctr addObserver: self selector: @selector(finishActiveOperations)
                     name: UIApplicationDidEnterBackgroundNotification object: app];
        [nctr addObserver: self selector: @selector(finishActiveOperations)
                     name: UIApplicationWillTerminateNotification object: app];
#else
        [nctr addObserver: self selector: @selector(finishActiveOperations)
                     name: NSApplicationWillTerminateNotification object: NSApp];
#endif
        _onStartBlock();
        notificationToPost = CouchEmbeddedServerDidStartNotification;
    } else {
        notificationToPost = CouchEmbeddedServerDidRestartNotification;
    }
    [nctr postNotificationName: notificationToPost object: self];
}


-(void)couchbaseMobile:(CouchbaseMobile*)couchbase failedToStart:(NSError*)error {
    self.error = error;
    _onStartBlock();
}

-(void)couchbase:(CouchbaseMobile*)couchbase didStart:(NSURL*)serverURL {
    [self couchbaseMobile: couchbase didStart: serverURL];
}
-(void)couchbase:(CouchbaseMobile*)couchbase failedToStart:(NSError*)error {
    [self couchbaseMobile: couchbase failedToStart: error];
}


@synthesize error = _error;


- (BOOL) running {
    return _couchbase==nil || _couchbase.serverURL != nil;
}


- (BOOL) isEmbeddedServer {
    return _couchbase != nil;
}


- (void) finishActiveOperations {
    COUCHLOG(@"CouchEmbeddedServer: Finishing active operations");
    [RESTOperation wait: self.activeOperations];
}


@end
