//
//  CouchDesignDocument_Embedded.m
//  CouchCocoa
//
//  Created by Jens Alfke on 10/3/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchDesignDocument_Embedded.h"
#import "CouchbaseViewRegistry.h"


NSString* const kCouchLanguageObjectiveC = @"objc";


@implementation CouchDesignDocument (Embedded)


+ (CouchbaseViewRegistry*) objCViewRegistry {
    static CouchbaseViewRegistry* sRegistry;
    if (!sRegistry) {
        Class regClass = NSClassFromString(@"CouchbaseViewRegistry");
        sRegistry = [regClass performSelector: @selector(sharedInstance)];
    }
    return sRegistry;
}


- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (CouchDesignDocumentMapBlock)mapBlock
{
    [self defineViewNamed: viewName mapBlock: mapBlock reduceBlock: NULL];
}


- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (CouchDesignDocumentMapBlock)mapBlock
             reduceBlock: (CouchDesignDocumentReduceBlock)reduceBlock
{
    NSString* mapKey = nil, *reduceKey = nil;
    if (mapBlock) {
        CouchbaseViewRegistry* registry = [[self class] objCViewRegistry];
        if (!registry)
            [NSException raise: NSGenericException format: @"No Objective-C views available"];

        mapKey = [self mapFunctionOfViewNamed: viewName];
        if (!mapKey)
            mapKey = [registry generateKey];
        [registry registerMapBlock: mapBlock forKey: mapKey];
        reduceKey = [self reduceFunctionOfViewNamed: viewName];
        if (reduceBlock) {
            if (!reduceKey)
                reduceKey = [registry generateKey];
        }
        if (reduceKey)
            [registry registerReduceBlock: reduceBlock forKey: reduceKey];
        self.language = kCouchLanguageObjectiveC;
    }
    [self defineViewNamed: viewName map: mapKey reduce: reduceKey];
}


@end
