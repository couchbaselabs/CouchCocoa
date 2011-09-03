//
//  CouchTestCase.m
//  CouchCocoa
//
//  Created by Jens Alfke on 9/2/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchTestCase.h"
#import "CouchInternal.h"
#import "CouchDesignDocument.h"


@implementation CouchTestCase


- (void) setUp {
    gRESTWarnRaisesException = YES;
    [self raiseAfterFailure];
    
    _server = [[CouchServer alloc] init];  // local server
    STAssertNotNil(_server, @"Couldn't create server object");
    _server.tracksActiveOperations = YES;
    
    _db = [[_server databaseNamed: @"testdb_temporary"] retain];
    STAssertNotNil(_db, @"Couldn't create database object");
    RESTOperation* op = [_db create];
    if (![op wait]) {
        NSLog(@"NOTE: DB '%@' exists; deleting and re-creating it for tests", _db.relativePath);
        STAssertEquals(op.httpStatus, 412,
                       @"Unexpected error creating db: %@", op.error);
        AssertWait([_db DELETE]);
        AssertWait([_db create]);
    }
    
    gRESTLogLevel = kRESTLogRequestHeaders; // kRESTLogNothing;
}


- (void) tearDown {
    gRESTLogLevel = kRESTLogNothing;
    AssertWait([_db DELETE]);
    STAssertEquals(_server.activeOperations.count, (NSUInteger)0, nil);
    [_db release];
    _db = nil;
    [_server release];
    _server = nil;
}


@synthesize db = _db;


@end
