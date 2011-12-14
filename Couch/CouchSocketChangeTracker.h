//
//  CouchSocketChangeTracker.h
//  CouchCocoa
//
//  Created by Jens Alfke on 12/2/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchChangeTracker.h"


/** CouchChangeTracker implementation that uses a raw TCP socket to read the chunk-mode HTTP response. */
@interface CouchSocketChangeTracker : CouchChangeTracker
{
    @private
    NSInputStream* _trackingInput;
    NSOutputStream* _trackingOutput;
    NSString* _trackingRequest;
    int _retryCount;
    
    NSMutableData* _inputBuffer;
    int _state;
}
@end
