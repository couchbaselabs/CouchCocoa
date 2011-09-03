//
//  CouchTestCase.h
//  CouchCocoa
//
//  Created by Jens Alfke on 9/2/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
@class CouchServer, CouchDatabase;


@interface CouchTestCase : SenTestCase
{
    CouchServer* _server;
    CouchDatabase* _db;
}

@property (readonly) CouchDatabase* db;

@end


// Waits for a RESTOperation to complete and raises an assertion failure if it got an error.
#define AssertWait(OP) ({RESTOperation* i_op = (OP);\
                        STAssertTrue([i_op wait], @"%@ failed: %@", i_op, i_op.error);\
                        i_op = i_op;})


