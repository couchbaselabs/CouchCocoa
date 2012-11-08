//
//  CouchDesignDocument_Embedded.m
//  CouchCocoa
//
//  Created by Jens Alfke on 10/3/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchDesignDocument_Embedded.h"
#import "CouchTouchDBServer.h"
#import "CouchDatabase.h"


// Redeclare API from TouchDB to avoid having to #include external headers:
typedef unsigned TDContentOptions;
enum {
    kTDIncludeLocalSeq = 16                // adds '_local_seq' property
};

@class TD_Database, TD_Revision, TD_View;

@interface TD_Server : NSObject
- (TD_Database*) databaseNamed: (NSString*)name;
@end

@interface TD_Database : NSObject
- (TD_View*) viewNamed: (NSString*)name;
- (TD_View*) existingViewNamed: (NSString*)name;
- (void) defineFilter: (NSString*)filterName asBlock: (TD_FilterBlock)filterBlock;
- (void) defineValidation: (NSString*)validationName asBlock: (TD_ValidationBlock)validationBlock;
- (TD_ValidationBlock) validationNamed: (NSString*)validationName;
@end

@interface TD_View : NSObject
- (BOOL) setMapBlock: (TDMapBlock)mapBlock
         reduceBlock: (TDReduceBlock)reduceBlock
             version: (NSString*)version;
- (void) deleteView;
@property TDContentOptions mapContentOptions;
@end



@implementation CouchDesignDocument (Embedded)


- (void) tellTDDatabase: (void(^)(TD_Database*))block {
    [(CouchTouchDBServer*)self.database.server tellTDDatabaseNamed: self.database.relativePath
                                                                to: block];
}


- (NSString*) qualifiedName: (NSString*)name {
    return [NSString stringWithFormat: @"%@/%@", self.relativePath.lastPathComponent, name];
}


- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (TDMapBlock)mapBlock
                 version: (NSString*)version
{
    [self defineViewNamed: viewName mapBlock: mapBlock reduceBlock: NULL version: version];
}


- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (TDMapBlock)mapBlock
             reduceBlock: (TDReduceBlock)reduceBlock
                 version: (NSString*)version
{
    NSAssert(mapBlock || !reduceBlock, @"Can't set a reduce block without a map block");
    viewName = [self qualifiedName: viewName];
    mapBlock = [mapBlock copy];
    reduceBlock = [reduceBlock copy];
    TDContentOptions mapContentOptions = self.includeLocalSequence ? kTDIncludeLocalSeq : 0;
    [self tellTDDatabase: ^(TD_Database* tddb) {
        if (mapBlock) {
            TD_View* view = [tddb viewNamed: viewName];
            [view setMapBlock: mapBlock reduceBlock: reduceBlock version: version];
            view.mapContentOptions = mapContentOptions;
        } else {
            [[tddb existingViewNamed: viewName] deleteView];
        }
    }];
    [mapBlock release];
    [reduceBlock release];
}


- (void) defineFilterNamed: (NSString*)filterName
                     block: (TD_FilterBlock)filterBlock
{
    filterName = [self qualifiedName: filterName];
    filterBlock = [filterBlock copy];
    [self tellTDDatabase: ^(TD_Database* tddb) {
        [tddb defineFilter: filterName asBlock: filterBlock];
    }];
    [filterBlock release];
}


- (void) setValidationBlock: (TD_ValidationBlock)validateBlock {
    validateBlock = [validateBlock copy];
    [self tellTDDatabase: ^(TD_Database* tddb) {
        [tddb defineValidation: self.relativePath asBlock: validateBlock];
    }];
    [validateBlock release];
}


@end
