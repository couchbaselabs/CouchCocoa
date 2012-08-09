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
    kTDIncludeUpdateSeq = 256                // adds '_update_seq' property
};

@class TDDatabase, TDRevision, TDView;

@interface TDServer : NSObject
- (TDDatabase*) databaseNamed: (NSString*)name;
@end

@interface TDDatabase : NSObject
- (TDView*) viewNamed: (NSString*)name;
- (TDView*) existingViewNamed: (NSString*)name;
- (void) defineFilter: (NSString*)filterName asBlock: (TDFilterBlock)filterBlock;
- (void) defineValidation: (NSString*)validationName asBlock: (TDValidationBlock)validationBlock;
- (TDValidationBlock) validationNamed: (NSString*)validationName;
@end

@interface TDView : NSObject
- (BOOL) setMapBlock: (TDMapBlock)mapBlock
         reduceBlock: (TDReduceBlock)reduceBlock
             version: (NSString*)version;
- (void) deleteView;
@property TDContentOptions mapContentOptions;
@end



@implementation CouchDesignDocument (Embedded)


- (void) tellTDDatabase: (void(^)(TDDatabase*))block {
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
    viewName = [self qualifiedName: viewName];
    mapBlock = [mapBlock copy];
    reduceBlock = [reduceBlock copy];
    [self tellTDDatabase: ^(TDDatabase* tddb) {
        if (mapBlock) {
            TDView* view = [tddb viewNamed: viewName];
            [view setMapBlock: mapBlock reduceBlock: reduceBlock version: version];
            view.mapContentOptions = self.includeLocalSequence ? kTDIncludeUpdateSeq : 0;
        } else {
            NSAssert(!reduceBlock, @"Can't set a reduce block without a map block");
            [[tddb existingViewNamed: viewName] deleteView];
        }
    }];
    [mapBlock release];
    [reduceBlock release];
}


- (void) defineFilterNamed: (NSString*)filterName
                     block: (TDFilterBlock)filterBlock
{
    filterName = [self qualifiedName: filterName];
    filterBlock = [filterBlock copy];
    [self tellTDDatabase: ^(TDDatabase* tddb) {
        [tddb defineFilter: filterName asBlock: filterBlock];
    }];
    [filterBlock release];
}


- (void) setValidationBlock: (TDValidationBlock)validateBlock {
    validateBlock = [validateBlock copy];
    [self tellTDDatabase: ^(TDDatabase* tddb) {
        [tddb defineValidation: self.relativePath asBlock: validateBlock];
    }];
    [validateBlock release];
}


@end
