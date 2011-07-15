//
//  DemoAppController.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class CouchDatabase, DemoQuery;


/** Generic application delegate for simple Mac OS CouchDB demo apps.
    The name of the (local) database to use should be added to the app's Info.plist
    under the 'DemoDatabase' key. */
@interface DemoAppController : NSObject
{
    IBOutlet NSWindow* _window;

    CouchDatabase* _database;
    DemoQuery* _view;
}

@property (retain) DemoQuery* view;

@end
