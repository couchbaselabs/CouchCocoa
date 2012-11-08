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


// Declared in TD_Database.h and TD_Revision.h; redeclare here to avoid linking against TouchDB:
static NSString* const TD_DatabaseChangeNotification = @"TD_DatabaseChange";

@interface TD_Revision : NSObject
@property (readonly) NSString* docID;
@property (readonly) NSString* revID;
@property (readonly) BOOL deleted;
@property SInt64 sequence;
@end


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
                                                           to: ^(TD_Database* tddb) {
            [[NSNotificationCenter defaultCenter] addObserver: self
                                                    selector: @selector(tdDatabaseChanged:)
                                                        name: TD_DatabaseChangeNotification
                                                      object: tddb];
        }];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: TD_DatabaseChangeNotification
                                                      object: nil];
    }
}


- (void) tdDatabaseChanged: (NSNotification*)n {
    // Careful! This method is called on the TouchDB background thread!
    if (!_tracking)
        return;
    
    NSDictionary* userInfo = n.userInfo;
    TD_Revision* rev = [userInfo objectForKey: @"winner"];  // I want winning rev, not newest one
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
