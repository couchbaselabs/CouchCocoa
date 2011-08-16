//
//  DemoItem.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "DemoItem.h"
#import <CouchCocoa/CouchCocoa.h>


@interface DemoItem ()
@property (readwrite, retain) CouchDocument* document;
@end


@implementation DemoItem

- (id)init {
    self = [super init];
    if (self) {
        NSLog(@"DEMOITEM: <%p> init", self);
    }
    return self;
}

- (id) initWithDocument: (CouchDocument*)document
{
    self = [super init];
    if (self) {
        NSLog(@"DEMOITEM: <%p> initWithDocument: %@ @%p", self, document, document);
        self.document = document;
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
    [_properties release];
    [_changedProperties release];
    [super dealloc];
}


- (CouchDocument*) document {
    return _document;
}


- (void) setDocument:(CouchDocument *)document {
    NSAssert(!_document && document, @"Can't change or clear document");
    NSAssert(document.modelObject == nil, @"Document already has a model");
    _document = [document retain];
    _document.modelObject = self;
}


- (CouchDatabase*) database {
    return _document.database;
}


- (void) setDatabase: (CouchDatabase*)db {
    if (db) {
        // On setting database, create a new untitled/unsaved CouchDocument:
        self.document = [db untitledDocument];
        NSLog(@"DEMOITEM: <%p> create %@ @%p", self, _document, _document);
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


// Respond to an external change (likely from sync)
- (void) couchDocumentChanged: (CouchDocument*)doc {
    NSAssert(doc == _document, @"Notified for wrong document");
    NSLog(@"DEMOITEM: <%p> External change to %@", self, _document);
    [self markExternallyChanged];
    if (_properties || _changedProperties) {
        NSArray* keys = [(_changedProperties ?: _properties) allKeys];
        for (id key in keys)
            [self willChangeValueForKey: key];
        [_properties release];
        _properties = nil;
        [_changedProperties release];
        _changedProperties = nil;
        for (id key in keys)
            [self didChangeValueForKey: key];
    }
}


- (void) markExternallyChanged {
    _changedTime = CFAbsoluteTimeGetCurrent();
}


- (NSTimeInterval) timeSinceExternallyChanged {
    return CFAbsoluteTimeGetCurrent() - _changedTime;
}


- (void) saveCompleted: (RESTOperation*)op {
    if (op.error) {
        [self couchDocumentChanged: _document];     // reset to contents from server
        [NSApp presentError: op.error];
    } else {
        [_properties release];
        _properties = nil;
        [_changedProperties release];
        _changedProperties = nil;
    }
}


- (void) save {
    if (_changedProperties) {
        NSLog(@"DEMOITEM: <%p> Saving %@", self, _document);
        RESTOperation* op = [_document putProperties:_changedProperties];
        [op onCompletion: ^{[self saveCompleted: op];}];
        [op start];
    }
}


- (NSDictionary*) properties {
    if (_changedProperties)
        return _changedProperties;
    if (!_properties)
        _properties = [_document.properties copy];
    return _properties;
}


// Key-value coding: delegate to _properties (or _changedProperties, if it exists)

- (id) valueForKey: (id)key {
    return [self.properties objectForKey: key];
}


- (void) setValue: (id)value forKey: (id)key {
    NSParameterAssert(_document);
    id curValue = [self.properties objectForKey: key];
    if (![value isEqual: curValue]) {
        NSLog(@"DEMOITEM: <%p> .%@ := \"%@\"", self, key, value);
        [self willChangeValueForKey: key];
        if (!_changedProperties) {
            _changedProperties = _properties ? [_properties mutableCopy] 
                                             : [[NSMutableDictionary alloc] init];
        }
        [_changedProperties setObject: value forKey: key];
        [self didChangeValueForKey: key];

        [self performSelector: @selector(save) withObject: nil afterDelay: 0.0];
    }
}

@end
