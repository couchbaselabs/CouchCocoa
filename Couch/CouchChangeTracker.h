//
//  CouchChangeTracker.h
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

#import <Foundation/Foundation.h>
@class CouchChangeTracker;


@protocol CouchChangeTrackerClient <NSObject>
- (void) changeTrackerReceivedChange: (NSDictionary*)change;
@optional
- (NSURLCredential*) authCredential;
- (void) changeTrackerStopped: (CouchChangeTracker*)tracker;
@end


typedef enum CouchChangeTrackerMode {
    kOneShot,
    kLongPoll,
    kContinuous
} CouchChangeTrackerMode;


/** Reads the continuous-mode _changes feed of a database, and sends the individual change entries to its client's -changeTrackerReceivedChange:.
    This class is used internally by CouchDatabase and you shouldn't need to use it yourself. */
@interface CouchChangeTracker : NSObject <NSStreamDelegate>
{
    @protected
    NSURL* _databaseURL;
    id<CouchChangeTrackerClient> _client;
    CouchChangeTrackerMode _mode;
    NSUInteger _lastSequenceNumber;
}

- (id)initWithDatabaseURL: (NSURL*)databaseURL
                     mode: (CouchChangeTrackerMode)mode
             lastSequence: (NSUInteger)lastSequence
                   client: (id<CouchChangeTrackerClient>)client;

@property (readonly, nonatomic) NSURL* databaseURL;
@property (readonly, nonatomic) NSString* databaseName;
@property (readonly, nonatomic) CouchChangeTrackerMode mode;
@property (readonly, nonatomic) NSUInteger lastSequenceNumber;

- (BOOL) start;
- (void) stop;

// Protected
@property (readonly) NSURLCredential* authCredential;
@property (readonly) NSURL* changesFeedURL;
@property (readonly) NSString* changesFeedPath;
- (void) receivedChunk: (NSData*)chunk;
- (BOOL) receivedPollResponse: (NSData*)body;
- (void) stopped; // override this

@end
