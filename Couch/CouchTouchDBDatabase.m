//
//  CouchTouchDBDatabase.m
//  CouchCocoa
//
//  Created by Jens Alfke on 5/25/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "CouchTouchDBDatabase.h"
#import "CouchTouchDBServer.h"
#import "CouchInternal.h"

#import "TDDatabase.h"
#import "TDRevision.h"


@implementation CouchTouchDBDatabase


- (BOOL) tracksChanges {
    return _tracking;
}

- (void) setTracksChanges: (BOOL)track {
    if (track == _tracking)
        return;
    _tracking = track;
    
    if (track) {
        [(CouchTouchDBServer*)self.parent tellTDDatabaseNamed: self.relativePath
                                                           to: ^(TDDatabase* tddb) {
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                    selector: @selector(tdDatabaseChanged:)
                                                        name: TDDatabaseChangeNotification
                                                      object: tddb];
        }];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: TDDatabaseChangeNotification
                                                      object: nil];
    }
}


- (void) tdDatabaseChanged: (NSNotification*)n {
    // Careful! This method is called on the TouchDB background thread!
    if (!_tracking)
        return;
    
    NSDictionary* userInfo = n.userInfo;
    TDRevision* rev = [userInfo objectForKey: @"winner"];  // I want winning rev, not newest one
    if (!rev)
        return;
    SInt64 sequence = [[userInfo objectForKey: @"rev"] sequence];

    // Adapted from -[TDRouter changeDictForRev:]
    NSArray* changes = [NSArray arrayWithObject: [NSDictionary dictionaryWithObject: rev.revID
                                                                             forKey: @"rev"]];
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithLongLong: sequence], @"seq",
                          rev.docID, @"id",
                          changes, @"changes",
                          [NSNumber numberWithBool: rev.deleted], @"deleted",
                          nil];
    [self performSelectorOnMainThread: @selector(changeTrackerReceivedChange:)
                           withObject: dict
                        waitUntilDone: NO];
}


@end
