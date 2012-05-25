//
//  CouchTouchDBDatabase.h
//  CouchCocoa
//
//  Created by Jens Alfke on 5/25/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "CouchDatabase.h"

@interface CouchTouchDBDatabase : CouchDatabase
{
    @private
    BOOL _tracking;
}

@end
