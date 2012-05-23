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


static CouchModelFactory* sSharedInstance;


+ (CouchModelFactory*) sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sSharedInstance = [[self alloc] init];
    });
    return sSharedInstance;
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
    if (!klass && self != sSharedInstance)
        return [sSharedInstance classForDocumentType: type];
    if ([klass isKindOfClass: [NSString class]]) {
        NSString* className = klass;
        klass = NSClassFromString(className);
        NSAssert(klass, @"CouchModelFactory: no class named %@", className);
    }
    return klass;
}


- (Class) classForDocument: (CouchDocument*)document {
    NSString* type = [document propertyForKey: @"type"];
    return type ? [self classForDocumentType: type] : nil;
}


- (id) modelForDocument: (CouchDocument*)document {
    CouchModel* model = document.modelObject;
    if (model)
        return model;
    return [[self classForDocument: document] modelForDocument: document];
}


@end




@implementation CouchDatabase (CouchModelFactory)

- (CouchModelFactory*) modelFactory {
    if (!_modelFactory)
        _modelFactory = [[CouchModelFactory alloc] init];
    return _modelFactory;
}

- (void) setModelFactory:(CouchModelFactory *)modelFactory {
    [_modelFactory autorelease];
    _modelFactory = [modelFactory retain];
}

@end