//
//  DemoItem.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class CouchDatabase, CouchDocument;


@interface DemoItem : NSObject
{
    CouchDocument* _document;
    NSDictionary* _properties;
    NSMutableDictionary* _changedProperties;
}

+ (DemoItem*) itemForDocument: (CouchDocument*)document;

- (id) init;
- (id) initWithDocument: (CouchDocument*)document;

@property (retain) CouchDatabase* database;

- (void) save;

@end
