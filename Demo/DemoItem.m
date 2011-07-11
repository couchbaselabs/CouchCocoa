//
//  DemoItem.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "DemoItem.h"
#import "Couch.h"
#import "RESTOperation.h"


@implementation DemoItem

- (id)init {
    self = [super init];
    if (self) {
        _changedContents = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id) initWithDocument: (CouchDocument*)document
{
    self = [super init];
    if (self) {
        _document = [document retain];
        _changedContents = [document.properties mutableCopy];
        if (!_changedContents)
            _changedContents = [[NSMutableDictionary alloc] init];
    }
    return self;
}


- (void) dealloc
{
    [_document release];
    [_changedContents release];
    [super dealloc];
}


- (CouchDatabase*) database {
    return _document.database;
}


- (void) setDatabase: (CouchDatabase*)db {
    if (db) {
        // On setting database, create a new untitled/unsaved CouchDocument:
        NSParameterAssert(!_document);
        _document = [[db untitledDocument] retain];
    } else if (_document) {
        // On clearing database, delete the document:
        [[_document DELETE] start];
        [_document release];
        _document = nil;
        [_changedContents release];
        _changedContents = nil;
    }
}


- (void) save {
    if (_changedContents) {
        [[_document putProperties:_changedContents] start]; //TODO: Error handling
        [_changedContents release];
        _changedContents = nil;
    }
}


// Key-value coding: delegate to _contents

- (id) valueForKey: (id)key {
    if (_changedContents)
        return [_changedContents objectForKey: key];
    else
        return [_document propertyForKey: key];
}


- (void) setValue: (id)value forKey: (id)key {
    NSParameterAssert(_document);
    if (![value isEqual: [self valueForKey: key]]) {
        if (!_changedContents) {
            _changedContents = [_document.properties mutableCopy];
            if (!_changedContents)
                _changedContents = [[NSMutableDictionary alloc] init];
        }
        [_changedContents setObject: value forKey: key];

        [self performSelector: @selector(save) withObject: nil afterDelay: 0.0];
    }
}

@end
