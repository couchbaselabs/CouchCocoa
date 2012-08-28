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

#import "TDDatabase+Insertion.h"
#import "TDView.h"
#import "TDServer.h"


@implementation CouchDesignDocument (Embedded)


- (void) tellTDDatabase: (void(^)(TDDatabase*))block {
    [(CouchTouchDBServer*)self.database.server tellTDDatabaseNamed: self.database.relativePath
                                                                to: block];
}


- (NSString*) qualifiedName: (NSString*)name {
    return [NSString stringWithFormat: @"%@/%@", self.relativePath.lastPathComponent, name];
}


- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (CouchMapBlock)mapBlock
                 version: (NSString*)version
{
    [self defineViewNamed: viewName mapBlock: mapBlock reduceBlock: NULL version: version];
}


- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (CouchMapBlock)mapBlock
             reduceBlock: (CouchReduceBlock)reduceBlock
                 version: (NSString*)version
{
    NSAssert(mapBlock || !reduceBlock, @"Can't set a reduce block without a map block");
    viewName = [self qualifiedName: viewName];
    mapBlock = [mapBlock copy];
    reduceBlock = [reduceBlock copy];
    TDContentOptions mapContentOptions = self.includeLocalSequence ? kTDIncludeLocalSeq : 0;
    [self tellTDDatabase: ^(TDDatabase* tddb) {
        if (mapBlock) {
            TDView* view = [tddb viewNamed: viewName];
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
                     block: (CouchFilterBlock)filterBlock
{
    filterBlock = [filterBlock copy];
    filterName = [self qualifiedName: filterName];
    filterBlock = [filterBlock copy];
    [self tellTDDatabase: ^(TDDatabase* tddb) {
        [tddb defineFilter: filterName asBlock: ^(TDRevision* rev, NSDictionary* params) {
            return filterBlock(rev.properties, params);
        }];
    }];
    [filterBlock release];
}


- (void) setValidationBlock: (CouchValidationBlock)validateBlock {
    validateBlock = [validateBlock copy];
    [self tellTDDatabase: ^(TDDatabase* tddb) {
        [tddb defineValidation: self.relativePath
                       asBlock: (TDValidationBlock)validateBlock];
    }];
    [validateBlock release];
}


@end
