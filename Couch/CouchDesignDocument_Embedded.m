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
@class TDDatabase, TDView;

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
@end



@implementation CouchDesignDocument (Embedded)


- (TDDatabase*) touchDatabase {
    TDServer* touchServer = [(CouchTouchDBServer*)self.database.server touchServer];
    return [touchServer databaseNamed: self.database.relativePath];
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
    if (mapBlock) {
        TDView* view = [self.touchDatabase viewNamed: viewName];
        [view setMapBlock: mapBlock reduceBlock: reduceBlock version: version];
    } else {
        NSAssert(!reduceBlock, @"Can't set a reduce block without a map block");
        [[self.touchDatabase existingViewNamed: viewName] deleteView];
    }
}


- (void) defineFilterNamed: (NSString*)filterName
                     block: (TDFilterBlock)filterBlock
{
    filterName = [self qualifiedName: filterName];
    [self.touchDatabase defineFilter: filterName asBlock: filterBlock];
}


- (TDValidationBlock) validationBlock {
    return [self.touchDatabase validationNamed: self.relativePath];
}

- (void) setValidationBlock: (TDValidationBlock)validateBlock {
    [self.touchDatabase defineValidation: self.relativePath asBlock: validateBlock];
}


@end
