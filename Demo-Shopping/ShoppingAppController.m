//
//  ShoppingAppController.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "ShoppingAppController.h"
#import "DemoQuery.h"
#import "Couch.h"
#import "RESTOperation.h"


static NSString* const kDatabaseName = @"demo-shopping";


@implementation ShoppingAppController


@synthesize view = _view;


- (void) applicationDidFinishLaunching: (NSNotification*)n {
    gRESTLogLevel = kRESTLogRequestHeaders;

    CouchServer *server = [[CouchServer alloc] init];
    _database = [[server databaseNamed: kDatabaseName] retain];
    [server release];
    
    RESTOperation* op = [_database create];
    if (![op wait]) {
        NSAssert(op.error.code == 412, @"Error creating db: %@", op.error);
    }
    
    self.view = [[[DemoQuery alloc] initWithQuery: [_database getAllDocuments]] autorelease];
}


@end




int main (int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
