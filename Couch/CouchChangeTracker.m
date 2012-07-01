//
//  CouchChangeTracker.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/20/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.
//
// <http://wiki.apache.org/couchdb/HTTP_database_API#Changes>

#import "CouchChangeTracker.h"
#import "CouchConnectionChangeTracker.h"
#import "CouchSocketChangeTracker.h"
#import "CouchInternal.h"


@implementation CouchChangeTracker

@synthesize lastSequenceNumber=_lastSequenceNumber, databaseURL=_databaseURL, mode=_mode;

- (id)initWithDatabaseURL: (NSURL*)databaseURL
                     mode: (CouchChangeTrackerMode)mode
             lastSequence: (NSUInteger)lastSequence
                   client: (id<CouchChangeTrackerClient>)client {
    NSParameterAssert(databaseURL);
    NSParameterAssert(client);
    self = [super init];
    if (self) {
        if ([self class] == [CouchChangeTracker class]) {
            [self release];
            if (mode == kContinuous && [databaseURL.scheme.lowercaseString hasPrefix: @"http"]) {
                return (id) [[CouchSocketChangeTracker alloc] initWithDatabaseURL: databaseURL
                                                                             mode: mode
                                                                     lastSequence: lastSequence
                                                                           client: client];
            } else {
                return (id) [[CouchConnectionChangeTracker alloc] initWithDatabaseURL: databaseURL
                                                                                 mode: mode
                                                                         lastSequence: lastSequence
                                                                               client: client];
            }
        }
    
        _databaseURL = [databaseURL retain];
        _client = client;
        _mode = mode;
        _lastSequenceNumber = lastSequence;
    }
    return self;
}

- (NSString*) databaseName {
    return _databaseURL.lastPathComponent;
}

- (NSString*) changesFeedPath {
    static NSString* const kModeNames[3] = {@"normal", @"longpoll", @"continuous"};
    return [NSString stringWithFormat: @"_changes?feed=%@&heartbeat=300000&since=%lu",
            kModeNames[_mode],
            (unsigned long)_lastSequenceNumber];
}

- (NSURL*) changesFeedURL {
    return [NSURL URLWithString: [NSString stringWithFormat: @"%@/%@",
                                  _databaseURL.absoluteString, self.changesFeedPath]];
}

- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@]", [self class], self.databaseName];
}

- (void)dealloc {
    [self stop];
    [_databaseURL release];
    [super dealloc];
}

- (NSURLCredential*) authCredential {
    if ([_client respondsToSelector: @selector(authCredential)])
        return _client.authCredential;
    else
        return nil;
}

- (BOOL) start {
    return NO;
}

- (void) stop {
    [self stopped];
}

- (void) stopped {
    if ([_client respondsToSelector: @selector(changeTrackerStopped:)])
        [_client changeTrackerStopped: self];
}

- (BOOL) receivedChange: (NSDictionary*)change {
    if (![change isKindOfClass: [NSDictionary class]])
        return NO;
    id seq = [change objectForKey: @"seq"];
    if (!seq)
        return NO;
    [_client changeTrackerReceivedChange: change];
    _lastSequenceNumber = [seq intValue];
    return YES;
}

- (void) receivedChunk: (NSData*)chunk {
    NSString* line = [[[NSString alloc] initWithData: chunk encoding:NSUTF8StringEncoding]
                      autorelease];
    if (!line) {
        Warn(@"Couldn't parse UTF-8 from _changes");
        return;
    }
    if (line.length == 0 || [line isEqualToString: @"\n"])
        return;
    id change = [RESTBody JSONObjectWithString: line];
    if (!change)
        Warn(@"Received unparseable change line from server: %@", line);
    else if (![self receivedChange: change]) {
        COUCHLOG(@"%@: Couldn't interpret change line %@", self, line);
    }
}

- (BOOL) receivedPollResponse: (NSData*)body {
    if (!body)
        return NO;
    NSDictionary* changeDict = $castIf(NSDictionary,
                                       [RESTBody JSONObjectWithData: body]);
    NSArray* changes = $castIf(NSArray, [changeDict objectForKey: @"results"]);
    if (!changes)
        return NO;
    for (NSDictionary* change in changes) {
        if (![self receivedChange: change])
            return NO;
    }
    return YES;
}

@end
