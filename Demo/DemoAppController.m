//
//  DemoAppController.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "DemoAppController.h"
#import "DemoQuery.h"
#import "Couch.h"
#import "RESTOperation.h"


@implementation DemoAppController


@synthesize view = _view;


- (void) applicationDidFinishLaunching: (NSNotification*)n {
    gRESTLogLevel = kRESTLogRequestHeaders;
    
    NSString* dbName = [[[NSBundle mainBundle] infoDictionary] objectForKey: @"DemoDatabase"];
    if (!dbName) {
        NSLog(@"FATAL: Please specify a CouchDB database name in the app's Info.plist under the 'DemoDatabase' key");
        exit(1);
    }

    CouchServer *server = [[CouchServer alloc] init];
    _database = [[server databaseNamed: dbName] retain];
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
