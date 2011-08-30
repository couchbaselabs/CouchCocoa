//
//  CouchModel.m
//  CouchCocoa
//
//  Created by Jens Alfke on 8/26/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchModel.h"
#import "CouchInternal.h"


@interface CouchModel ()
@property (readwrite, retain) CouchDocument* document;
@end


@implementation CouchModel


- (id)init {
    self = [super init];
    if (self) {
        COUCHLOG2(@"COUCHMODEL: <%p> init", self);
    }
    return self;
}

- (id) initWithDocument: (CouchDocument*)document
{
    self = [super init];
    if (self) {
        COUCHLOG2(@"COUCHMODEL: <%p> initWithDocument: %@ @%p", self, document, document);
        self.document = document;
    }
    return self;
}


+ (CouchModel*) modelForDocument: (CouchDocument*)document {
    CouchModel* model = document.modelObject;
    if (model)
        NSAssert([model isKindOfClass: self], @"%@ already has model of incompatible class %@",
                 document, [model class]);
    else
        model = [[[self alloc] initWithDocument: document] autorelease];
    return model;
}


- (void) dealloc
{
    COUCHLOG2(@"COUCHMODEL: <%p> dealloc; doc = %@", self, _document);
    _document.modelObject = nil;
    [_document release];
    [_properties release];
    [_changedProperties release];
    [super dealloc];
}


#pragma mark - DOCUMENT / DATABASE:


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
        COUCHLOG2(@"COUCHMODEL: <%p> create %@ @%p", self, _document, _document);
    } else if (_document) {
        // On clearing database, delete the document:
        COUCHLOG2(@"COUCHMODEL: <%p> Deleting %@", self, _document);
        [[_document DELETE] start];
        _document.modelObject = nil;
        [_document release];
        _document = nil;
    }
}


// Respond to an external change (likely from sync). This is called by my CouchDocument.
- (void) couchDocumentChanged: (CouchDocument*)doc {
    NSAssert(doc == _document, @"Notified for wrong document");
    COUCHLOG2(@"COUCHMODEL: <%p> External change to %@", self, _document);
    [self markExternallyChanged];
    
    if (_properties || _changedProperties) {
        // Send KVO notifications about all my properties in case they changed:
        NSArray* keys = [(_changedProperties ?: _properties) allKeys];
        for (id key in keys)
            [self willChangeValueForKey: key];
        // Update _properties:
        [_properties release];
        _properties = nil;
        [_changedProperties release];
        _changedProperties = nil;
        for (id key in keys)
            [self didChangeValueForKey: key];
    }
}


- (NSTimeInterval) timeSinceExternallyChanged {
    return CFAbsoluteTimeGetCurrent() - _changedTime;
}

- (void) markExternallyChanged {
    _changedTime = CFAbsoluteTimeGetCurrent();
}


#pragma mark - SAVING:


@synthesize autosaves=_autosaves, needsSave=_needsSave;


- (void) saveCompleted: (RESTOperation*)op {
    if (op.error) {
        // TODO: Need a way to inform the app (and user) of the error, and not just revert
        [self couchDocumentChanged: _document];     // reset to contents from server
        //[NSApp presentError: op.error];
    } else {
        [_properties release];
        _properties = nil;
        [_changedProperties release];
        _changedProperties = nil;
    }
}


- (void) save:(OnSaveBlock)saveBlock {
    if (_needsSave && _changedProperties) {
        COUCHLOG2(@"COUCHMODEL: <%p> Saving %@", self, _document);
        _needsSave = NO;
        RESTOperation* op = [_document putProperties:_changedProperties];
        [op onCompletion: ^{
          [self saveCompleted: op];
          saveBlock();
        }];
        [op start];
    }
}


#pragma mark - PROPERTIES:


- (NSDictionary*) propertyDictionary {
    if (_changedProperties)
        return _changedProperties;
    if (!_properties)
        _properties = [_document.properties copy];      // Synchronous!
    return _properties;
}


- (id) getValueOfProperty: (NSString*)property {
    return [self.propertyDictionary objectForKey: property];
}

- (BOOL) setValue: (id)value ofProperty: (NSString*)property {
    NSParameterAssert(_document);
    id curValue = [self.propertyDictionary objectForKey: property];
    if (![value isEqual: curValue]) {
        COUCHLOG2(@"COUCHMODEL: <%p> .%@ := \"%@\"", self, property, value);
        if (!_changedProperties) {
            _changedProperties = _properties ? [_properties mutableCopy] 
                                             : [[NSMutableDictionary alloc] init];
        }
        [_changedProperties setValue: value forKey: property];
        
        if (_autosaves && !_needsSave)
            [self performSelector: @selector(save) withObject: nil afterDelay: 0.0];
        _needsSave = YES;
    }
    return YES;
}


@end
