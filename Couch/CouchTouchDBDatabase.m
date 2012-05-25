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
#import <TouchDB/TDRevision.h>


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
    // Adapted from -[TDRouter changeDictForRev:]
    TDRevision* rev = [n.userInfo objectForKey: @"rev"];
    NSArray* changes = [NSArray arrayWithObject: [NSDictionary dictionaryWithObject: rev.revID
                                                                             forKey: @"rev"]];
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithLongLong: rev.sequence], @"seq",
                          rev.docID, @"id",
                          changes, @"changes",
                          [NSNumber numberWithBool: rev.deleted], @"deleted",
                          rev.properties, @"doc",       // may be nil
                          nil];
    [self performSelectorOnMainThread: @selector(changeTrackerReceivedChange:)
                           withObject: dict
                        waitUntilDone: NO];
}


@end
