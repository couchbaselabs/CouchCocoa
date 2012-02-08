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

- (CouchDatabase *)databaseNamed:(NSString *)databaseName
{
    CouchDatabase *database = [_server databaseNamed: databaseName];
    STAssertNotNil(database, @"Couldn't create database object");
    RESTOperation* op = [database create];
    if (![op wait]) {
        NSLog(@"NOTE: DB '%@' exists; deleting and re-creating it for tests", database.relativePath);
        STAssertEquals(op.httpStatus, 412,
                       @"Unexpected error creating db: %@", op.error);
        AssertWait([database DELETE]);
        AssertWait([database create]);
    }

    return database;
}

- (void) setUp {
    gRESTWarnRaisesException = YES;
    [self raiseAfterFailure];
    
    _server = [[CouchServer alloc] init];  // local server
    STAssertNotNil(_server, @"Couldn't create server object");
    _server.tracksActiveOperations = YES;
    
    _db = [[self databaseNamed:@"testdb_temporary"] retain];
    
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
