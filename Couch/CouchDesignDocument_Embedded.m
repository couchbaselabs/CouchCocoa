//
//  CouchDesignDocument_Embedded.m
//  CouchCocoa
//
//  Created by Jens Alfke on 10/3/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchDesignDocument_Embedded.h"


NSString* const kCouchLanguageObjectiveC = @"objc";


@implementation CouchDesignDocument (Embedded)


+ (CouchbaseCallbacks*) objCCallbacks {
    // Look up the callbacks without creating a link-time dependency on the class:
    static CouchbaseCallbacks* sCallbacks;
    if (!sCallbacks) {
        Class regClass = NSClassFromString(@"CouchbaseCallbacks");
        sCallbacks = [regClass performSelector: @selector(sharedInstance)];
        if (!sCallbacks)
            [NSException raise: NSGenericException format: @"No Objective-C views available"];
    }
    return sCallbacks;
}


- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (CouchMapBlock)mapBlock
{
    [self defineViewNamed: viewName mapBlock: mapBlock reduceBlock: NULL];
}


- (void) defineViewNamed: (NSString*)viewName
                mapBlock: (CouchMapBlock)mapBlock
             reduceBlock: (CouchReduceBlock)reduceBlock
{
    NSString* mapKey = nil, *reduceKey = nil;
    if (mapBlock) {
        CouchbaseCallbacks* callbacks = [[self class] objCCallbacks];
        mapKey = [self mapFunctionOfViewNamed: viewName];
        if (!mapKey)
            mapKey = [callbacks generateKey];
        [callbacks registerMapBlock: mapBlock forKey: mapKey];
        reduceKey = [self reduceFunctionOfViewNamed: viewName];
        if (reduceBlock) {
            if (!reduceKey)
                reduceKey = [callbacks generateKey];
        }
        if (reduceKey)
            [callbacks registerReduceBlock: reduceBlock forKey: reduceKey];
        self.language = kCouchLanguageObjectiveC;
    }
    [self defineViewNamed: viewName map: mapKey reduce: reduceKey];
}


- (CouchValidateUpdateBlock) validationBlock {
    if (![self.language isEqualToString: kCouchLanguageObjectiveC])
        return nil;
    NSString* validateKey = self.validation;
    if (!validateKey)
        return nil;
    return [[[self class] objCCallbacks] validateUpdateBlockForKey: validateKey];
}

- (void) setValidationBlock: (CouchValidateUpdateBlock)validateBlock {
    CouchbaseCallbacks* callbacks = [[self class] objCCallbacks];
    NSString* validateKey = self.validation;
    if (validateBlock) {
        if (!validateKey)
            validateKey = [callbacks generateKey];
        [callbacks registerValidateUpdateBlock: validateBlock forKey: validateKey];
        self.language = kCouchLanguageObjectiveC;
    } else if (validateKey) {
        [callbacks registerValidateUpdateBlock: nil forKey: validateKey];
        validateKey = nil;
    }
    self.validation = validateKey;
}


@end
