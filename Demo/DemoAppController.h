//
//  DemoAppController.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class CouchDatabase, DemoQuery;


@interface DemoAppController : NSObject
{
    IBOutlet NSWindow* _window;

    CouchDatabase* _database;
    DemoQuery* _view;
}

@property (retain) DemoQuery* view;

@end
