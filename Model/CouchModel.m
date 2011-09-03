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
@property (readwrite) bool needsSave;
@end


@implementation CouchModel


- (id)init {
    return [self initWithDocument: nil];
}

- (id) initWithDocument: (CouchDocument*)document
{
    self = [super init];
    if (self) {
        if (document) {
            COUCHLOG2(@"COUCHMODEL: <%p> initWithDocument: %@ @%p", self, document, document);
            self.document = document;
            [self didLoadFromDocument];
        } else {
            _isNew = true;
            COUCHLOG2(@"COUCHMODEL: <%p> init", self);
        }
    }
    return self;
}


+ (id) modelForDocument: (CouchDocument*)document {
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
    [_changedNames release];
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


- (NSString*) idForNewDocument {
    return nil;  // subclasses can override this to customize the doc ID
}


- (CouchDatabase*) database {
    return _document.database;
}


- (void) setDatabase: (CouchDatabase*)db {
    if (db) {
        // On setting database, create a new untitled/unsaved CouchDocument:
        NSString* docID = [self idForNewDocument];
        self.document = docID ? [db documentWithID: docID] : [db untitledDocument];
        COUCHLOG2(@"COUCHMODEL: <%p> create %@ @%p", self, _document, _document);
    } else {
        [self deleteDocument];
    }
}


- (void) deleteDocument {
    if (_document) {
        COUCHLOG2(@"COUCHMODEL: <%p> Deleting %@", self, _document);
        [[_document DELETE] start];
        _document.modelObject = nil;
        [_document release];
        _document = nil;
    }
}


- (void) didLoadFromDocument {
    // subclasses can override this
}


// Respond to an external change (likely from sync). This is called by my CouchDocument.
- (void) couchDocumentChanged: (CouchDocument*)doc {
    NSAssert(doc == _document, @"Notified for wrong document");
    COUCHLOG2(@"COUCHMODEL: <%p> External change to %@", self, _document);
    [self markExternallyChanged];
    
    if (_properties) {
        // Send KVO notifications about all my properties in case they changed:
        NSArray* keys = [_properties allKeys];
        for (id key in keys)
            [self willChangeValueForKey: key];
        // Reset _properties:
        [_properties release];
        _properties = nil;
        [_changedNames release];
        _changedNames = nil;
        [self didLoadFromDocument];
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


@synthesize isNew=_isNew, autosaves=_autosaves, needsSave=_needsSave;


- (void) saveCompleted: (RESTOperation*)op {
    if (op.error) {
        // TODO: Need a way to inform the app (and user) of the error, and not just revert
        [self couchDocumentChanged: _document];     // reset to contents from server
        //[NSApp presentError: op.error];
    } else {
        _isNew = NO;
        [_properties release];
        _properties = nil;
        [_changedNames release];
        _changedNames = nil;
    }
}


- (RESTOperation*) save {
    if (!_needsSave || !_changedNames)
        return nil;
    COUCHLOG2(@"COUCHMODEL: <%p> Saving %@", self, _document);
    self.needsSave = NO;
    RESTOperation* op = [_document putProperties: self.propertiesToSave];
    [op onCompletion: ^{[self saveCompleted: op];}];
    [op start];
    return op;
}


#pragma mark - PROPERTIES:


- (id) externalizePropertyValue: (id)value {
    if ([value isKindOfClass: [NSData class]])
        value = [RESTBody base64WithData: value];
    else if ([value isKindOfClass: [NSDate class]])
        value = [RESTBody JSONObjectWithDate: value];
    return value;
}


- (NSDictionary*) propertiesToSave {
    NSMutableDictionary* properties = [_document.properties mutableCopy];
    if (!properties)
        properties = [[NSMutableDictionary alloc] init];
    for (NSString* key in _changedNames) {
        id value = [_properties objectForKey: key];
        [properties setValue: [self externalizePropertyValue: value] forKey: key];
    }
    return properties;
}


- (void) cacheValue: (id)value ofProperty: (NSString*)property changed: (BOOL)changed {
    if (!_properties)
        _properties = [[NSMutableDictionary alloc] init];
    [_properties setValue: value forKey: property];
    if (changed) {
        if (!_changedNames)
            _changedNames = [[NSMutableSet alloc] init];
        [_changedNames addObject: property];
    }
}


- (id) getValueOfProperty: (NSString*)property {
    id value = [_properties objectForKey: property];
    if (!value && ![_changedNames containsObject: property]) {
        value = [_document propertyForKey: property];
    }
    return value;
}


- (BOOL) setValue: (id)value ofProperty: (NSString*)property {
    NSParameterAssert(_document);
    id curValue = [self getValueOfProperty: property];
    if (!$equal(value, curValue)) {
        COUCHLOG2(@"COUCHMODEL: <%p> .%@ := \"%@\"", self, property, value);
        [self cacheValue: value ofProperty: property changed: YES];
        if (_autosaves && !_needsSave)
            [self performSelector: @selector(save) withObject: nil afterDelay: 0.0];
        self.needsSave = YES;
    }
    return YES;
}


#pragma mark - PROPERTY TRANSFORMATIONS:


- (NSData*) getDataProperty: (NSString*)property {
    NSData* value = [_properties objectForKey: property];
    if (!value) {
        id rawValue = [_document propertyForKey: property];
        if ([rawValue isKindOfClass: [NSString class]])
            value = [RESTBody dataWithBase64: rawValue];
        if (value) 
            [self cacheValue: value ofProperty: property changed: NO];
        else if (rawValue)
            Warn(@"Unable to decode Base64 data from property %@ of %@", property, _document);
    }
    return value;
}

- (NSDate*) getDateProperty: (NSString*)property {
    NSDate* value = [_properties objectForKey: property];
    if (!value) {
        id rawValue = [_document propertyForKey: property];
        if ([rawValue isKindOfClass: [NSString class]])
            value = [RESTBody dateWithJSONObject: rawValue];
        if (value) 
            [self cacheValue: value ofProperty: property changed: NO];
        else if (rawValue)
            Warn(@"Unable to decode date from property %@ of %@", property, _document);
    }
    return value;
}

NS_INLINE NSString *getterKey(SEL sel) {
    return [NSString stringWithUTF8String:sel_getName(sel)];
}

static id getDataProperty(CouchModel *self, SEL _cmd) {
    return [self getDataProperty: getterKey(_cmd)];
}

static id getDateProperty(CouchModel *self, SEL _cmd) {
    return [self getDateProperty: getterKey(_cmd)];
}


+ (IMP) impForGetterOfClass: (Class)propertyClass {
    if (propertyClass == Nil || propertyClass == [NSString class]
             || propertyClass == [NSNumber class] || propertyClass == [NSArray class]
             || propertyClass == [NSDictionary class])
        return [super impForGetterOfClass: propertyClass];  // Basic classes (including 'id')
    else if (propertyClass == [NSData class])
        return (IMP)getDataProperty;
    else if (propertyClass == [NSDate class])
        return (IMP)getDateProperty;
    else 
        return NULL;  // Unsupported
}

@end
