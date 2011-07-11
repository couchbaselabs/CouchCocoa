//
//  CouchChangeTracker.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/20/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class CouchDatabase;


/** Reads the continuous-mode _changes feed of a database, and sends the individual lines to -[CouchDatabase receivedChangeChunk:].
    This class is used internally by CouchDatabase and you shouldn't need to use it yourself. */
@interface CouchChangeTracker : NSObject <NSStreamDelegate>
{
    @private
    CouchDatabase* _database;
    NSUInteger _lastSequenceNo;
    NSInputStream* _trackingInput;
    NSOutputStream* _trackingOutput;
    NSString* _trackingRequest;
    
    NSMutableData* _inputBuffer;
    int _state;
}

- (id)initWithDatabase: (CouchDatabase*)database sequenceNumber: (NSUInteger)lastSequenceNo;
- (BOOL) start;
- (void) stop;

@end
