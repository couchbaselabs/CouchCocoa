//
//  CouchModelFactory.m
//  CouchCocoa
//
//  Created by Jens Alfke on 11/22/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchModelFactory.h"
#import "CouchInternal.h"


@implementation CouchModelFactory


+ (CouchModelFactory*) sharedInstance {
    static CouchModelFactory* sInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sInstance = [[self alloc] init];
    });
    return sInstance;
}


- (id)init {
    self = [super init];
    if (self) {
        _typeDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}


- (void)dealloc {
    [_typeDict release];
    [super dealloc];
}


- (void) registerClass: (id)classOrName forDocumentType: (NSString*)type {
    [_typeDict setValue: classOrName forKey: type];
}


- (Class) classForDocumentType: (NSString*)type {
    id klass = [_typeDict objectForKey: type];
    if ([klass isKindOfClass: [NSString class]]) {
        NSString* className = klass;
        klass = NSClassFromString(className);
        NSAssert(klass, @"CouchModelFactory: no class named %@", className);
    }
    return klass;
}


- (id) modelForDocument: (CouchDocument*)document {
    CouchModel* model = document.modelObject;
    if (model)
        return model;
    NSString* type = [document propertyForKey: @"type"];
    if (!type)
        return nil;
    Class klass = [self classForDocumentType: type];
    return [klass modelForDocument: document];
}


@end
