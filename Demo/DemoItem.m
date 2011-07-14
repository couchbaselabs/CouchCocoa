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
        NSLog(@"DEMOITEM: <%p> init", self);
        //_changedContents = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id) initWithDocument: (CouchDocument*)document
{
    self = [super init];
    if (self) {
        NSLog(@"DEMOITEM: <%p> initWithDocument: %@", self, document);
        NSAssert(document.modelObject == nil, @"Document already has a model");
        _document = [document retain];
        _document.modelObject = self;
        _properties = [document.properties copy];
    }
    return self;
}


+ (DemoItem*) itemForDocument: (CouchDocument*)document {
    DemoItem* item = document.modelObject;
    if (!item)
        item = [[[self alloc] initWithDocument: document] autorelease];
    return item;
}


- (void) dealloc
{
    NSLog(@"DEMOITEM: <%p> dealloc; doc = %@", self, _document);
    _document.modelObject = nil;
    [_document release];
    [_changedProperties release];
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
        _document.modelObject = self;
        _properties = [_document.properties copy];
        NSLog(@"DEMOITEM: <%p> create %@", self, _document);
    } else if (_document) {
        // On clearing database, delete the document:
        NSLog(@"DEMOITEM: <%p> Deleting %@", self, _document);
        [[_document DELETE] start];
        _document.modelObject = nil;
        [_document release];
        _document = nil;
        [_changedProperties release];
        _changedProperties = nil;
    }
}


- (void) save {
    if (_changedProperties) {
        NSLog(@"DEMOITEM: <%p> Saving %@", self, _document);
        [[_document putProperties:_changedProperties] start]; //TODO: Error handling
        [_changedProperties release];
        _changedProperties = nil;
    }
}


// Respond to an external change (likely from sync)
- (void) couchDocumentChanged: (CouchDocument*)doc {
    NSDictionary* newProperties = doc.properties;
    NSDictionary* oldProperties = (_changedProperties ?: _properties);
    if (![newProperties isEqual: oldProperties]) {
        NSLog(@"DEMOITEM: <%p> External change to %@", self, _document);
        NSArray* keys = [oldProperties allKeys];
        for (id key in keys)
            [self willChangeValueForKey: key];
        [_properties release];
        _properties = [newProperties copy];
        [_changedProperties release];
        _changedProperties = nil;
        for (id key in keys)
            [self didChangeValueForKey: key];
        // TODO: This doesn't post KV notifications of *new* properties,
        // i.e. keys that exist in newProperties but not oldProperties.
    }
}



// Key-value coding: delegate to _contents

- (id) valueForKey: (id)key {
    if (_changedProperties)
        return [_changedProperties objectForKey: key];
    else
        return [_document propertyForKey: key];
}


- (void) setValue: (id)value forKey: (id)key {
    NSParameterAssert(_document);
    if (![value isEqual: [self valueForKey: key]]) {
        if (!_changedProperties) {
            _changedProperties = [_document.properties mutableCopy];
            if (!_changedProperties)
                _changedProperties = [[NSMutableDictionary alloc] init];
        }
        [_changedProperties setObject: value forKey: key];

        [self performSelector: @selector(save) withObject: nil afterDelay: 0.0];
    }
}

@end
