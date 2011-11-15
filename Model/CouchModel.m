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
- (NSDictionary*) attachmentDataToSave;
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
            COUCHLOG2(@"%@ initWithDocument: %@ @%p", self, document, document);
            self.document = document;
            [self didLoadFromDocument];
        } else {
            _isNew = true;
            COUCHLOG2(@"%@ init", self);
        }
    }
    return self;
}


- (id) initWithNewDocumentInDatabase: (CouchDatabase*)database {
    NSParameterAssert(database);
    self = [self initWithDocument: nil];
    if (self) {
        self.database = database;
    }
    return self;
}


+ (id) modelForDocument: (CouchDocument*)document {
    CouchModel* model = document.modelObject;
    if (model)
        NSAssert([model isKindOfClass: self], @"%@: %@ already has incompatible model %@",
                 self, document, model);
    else
        model = [[[self alloc] initWithDocument: document] autorelease];
    return model;
}


- (void) dealloc
{
    COUCHLOG2(@"%@ dealloc", self);
    _document.modelObject = nil;
    [_document release];
    [_properties release];
    [_changedNames release];
    [_changedAttachments release];
    [super dealloc];
}


- (NSString*) description {
    return [NSString stringWithFormat: @"%@[%@]", self.class, self.document.abbreviatedID];
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


- (void) detachFromDocument {
    _document.modelObject = nil;
    [_document release];
    _document = nil;
}


- (NSString*) idForNewDocumentInDatabase: (CouchDatabase*)db {
    return nil;  // subclasses can override this to customize the doc ID
}


- (CouchDatabase*) database {
    return _document.database;
}


- (void) setDatabase: (CouchDatabase*)db {
    if (db) {
        // On setting database, create a new untitled/unsaved CouchDocument:
        NSString* docID = [self idForNewDocumentInDatabase: db];
        self.document = docID ? [db documentWithID: docID] : [db untitledDocument];
        COUCHLOG2(@"%@ made new document", self);
    } else {
        [self deleteDocument];
        [self detachFromDocument];  // detach immediately w/o waiting for success
    }
}


- (RESTOperation*) deleteDocument {
    if (!_document)
        return nil;
    COUCHLOG2(@"%@ Deleting document", self);
    _needsSave = NO;        // prevent any pending saves
    RESTOperation* op = [_document DELETE];
    [op onCompletion:^{
        if (op.isSuccessful) 
            [self detachFromDocument];
    }];
    return op;
}


- (void) didLoadFromDocument {
    // subclasses can override this
}


// Respond to an external change (likely from sync). This is called by my CouchDocument.
- (void) couchDocumentChanged: (CouchDocument*)doc {
    NSAssert(doc == _document, @"Notified for wrong document");
    COUCHLOG2(@"%@ External change (rev=%@)", self, _document.currentRevisionID);
    [self markExternallyChanged];
    
    // Send KVO notifications about all my properties in case they changed:
    // TODO: This is not 100% accurate: won't notify on keys that got removed in new rev
    NSArray* keys = self.document.userProperties.allKeys;
    for (id key in keys)
        [self willChangeValueForKey: key];
    
    // Remove unchanged cached values in _properties:
    if (_changedNames && _properties) {
        NSMutableSet* removeKeys = [NSMutableSet setWithArray: [_properties allKeys]];
        [removeKeys minusSet: _changedNames];
        [_properties removeObjectsForKeys: removeKeys.allObjects];
    } else {
        [_properties release];
        _properties = nil;
    }
    
    [self didLoadFromDocument];
    for (id key in keys)
        [self didChangeValueForKey: key];
}


- (NSTimeInterval) timeSinceExternallyChanged {
    return CFAbsoluteTimeGetCurrent() - _changedTime;
}

- (void) markExternallyChanged {
    _changedTime = CFAbsoluteTimeGetCurrent();
}


#pragma mark - SAVING:


@synthesize isNew=_isNew, autosaves=_autosaves, needsSave=_needsSave;


- (void) markNeedsSave {
    if (_autosaves && !_needsSave)
        [self performSelector: @selector(save) withObject: nil afterDelay: 0.0];
    self.needsSave = YES;
}


- (void) saveCompleted: (RESTOperation*)op {
    if (op.error) {
        // TODO: Need a way to inform the app (and user) of the error, and not just revert
        Warn(@"%@: Save failed: %@", self, op.error);
        [self couchDocumentChanged: _document];     // reset to contents from server
        //[NSApp presentError: op.error];
    } else {
        _isNew = NO;
        [_properties release];
        _properties = nil;
        [_changedNames release];
        _changedNames = nil;
        [_changedAttachments release];
        _changedAttachments = nil;
    }
}


- (RESTOperation*) save {
    if (!_needsSave || (!_changedNames && !_changedAttachments))
        return nil;
    NSDictionary* properties = self.propertiesToSave;
    COUCHLOG2(@"%@ Saving <- %@", self, properties);
    self.needsSave = NO;
    RESTOperation* op = [_document putProperties: properties];
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
    [properties setValue: self.attachmentDataToSave forKey: @"_attachments"];
    return [properties autorelease];
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
        COUCHLOG2(@"%@ .%@ := \"%@\"", self, property, value);
        [self cacheValue: value ofProperty: property changed: YES];
        [self markNeedsSave];
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


#pragma mark - ATTACHMENTS:


- (NSArray*) attachmentNames {
    NSArray* names = [_document.currentRevision attachmentNames];
    if (!_changedAttachments)
        return names;
    
    NSMutableArray* nuNames = names ? [[names mutableCopy] autorelease] : [NSMutableArray array];
    for (NSString* name in _changedAttachments.allKeys) {
        CouchAttachment* attach = [_changedAttachments objectForKey: name];
        if ([attach isKindOfClass: [CouchAttachment class]]) {
            if (![nuNames containsObject: name])
                [nuNames addObject: name];
        } else
            [nuNames removeObject: name];
    }
    return nuNames;
}

- (CouchAttachment*) attachmentNamed: (NSString*)name {
    id attachment = [_changedAttachments objectForKey: name];
    if (attachment) {
        if ([attachment isKindOfClass: [CouchAttachment class]])
            return attachment;
        else
            return nil;
    }
    return [_document.currentRevision attachmentNamed: name];
}


- (CouchAttachment*) createAttachmentWithName: (NSString*)name
                                         type: (NSString*)contentType
                                         body: (NSData*)body
{
    NSParameterAssert(name);
    id attach = nil;
    if (body) {
        NSDictionary* metadata = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [RESTBody base64WithData: body], @"data",
                                  [NSNumber numberWithUnsignedLong: body.length], @"length",
                                  contentType, @"content_type",
                                  nil];
        attach = [[[CouchAttachment alloc] initWithParent: (_document.currentRevision ?: _document)
                                                     name: name
                                                 metadata: metadata] autorelease];
    } else if (![self attachmentNamed: name]) {
        return nil;
    }
    
    if (!_changedAttachments)
        _changedAttachments = [[NSMutableDictionary alloc] init];
    [_changedAttachments setObject: (attach ? attach : [NSNull null])
                            forKey: name];
    [self markNeedsSave];
    return attach;
}

- (void) removeAttachmentNamed: (NSString*)name {
    [self createAttachmentWithName: name type: nil body: nil];
}


- (NSDictionary*) attachmentDataToSave {
    NSDictionary* attachments = [_document.properties objectForKey: @"_attachments"];
    if (!_changedAttachments)
        return attachments;
    
    NSMutableDictionary* nuAttach = attachments ? [[attachments mutableCopy] autorelease]
                                                : [NSMutableDictionary dictionary];
    for (NSString* name in _changedAttachments.allKeys) {
        CouchAttachment* attach = [_changedAttachments objectForKey: name];
        if ([attach isKindOfClass: [CouchAttachment class]])
            [nuAttach setObject: attach.metadata forKey: name];
        else
            [nuAttach removeObjectForKey: name];
    }
    return nuAttach;
}


@end
