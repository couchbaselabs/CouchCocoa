//
//  CouchConnectionChangeTracker.h
//  CouchCocoa
//
//  Created by Jens Alfke on 12/1/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchChangeTracker.h"


/** CouchChangeTracker that uses a regular NSURLConnection.
    This unfortunately doesn't work with regular CouchDB in continuous mode, apparently due to some bug in CFNetwork. */
@interface CouchConnectionChangeTracker : CouchChangeTracker
{
    @private
    NSURLConnection* _connection;
    int _status;
    NSMutableData* _inputBuffer;
}

@end
