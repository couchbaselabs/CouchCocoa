//
//  CouchModel.m
//  CouchCocoa
//
//  Created by Jens Alfke on 8/26/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchModel.h"
#import "CouchModelFactory.h"
#import "CouchInternal.h"
#import <objc/runtime.h>


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
    NSParameterAssert(document);
    CouchModel* model = document.modelObject;
    if (model) {
        // Document already has a model; make sure it's type-compatible with the desired class
        NSAssert([model isKindOfClass: self], @"%@: %@ already has incompatible model %@",
                 self, document, model);
    } else if (self != [CouchModel class]) {
        // If invoked on a subclass of CouchModel, create an instance of that subclass:
        model = [[[self alloc] initWithDocument: document] autorelease];
    } else {
        // If invoked on CouchModel itself, ask the factory to instantiate the appropriate class:
        model = [document.database.modelFactory modelForDocument: document];
    }
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

- (RESTOperation*) deleteDocumentWithAdditionalProperties:(NSDictionary *)additionalProperties {
    
    if (!_document)
        return nil;
    
    COUCHLOG2(@"%@ Deleting document with additional properties", self);
    
    if (additionalProperties == nil) {
        additionalProperties = @{};
    }
    
    NSMutableDictionary* properties = [additionalProperties mutableCopy];
    [properties setValue:[NSNumber numberWithBool:TRUE] forKey:@"_deleted"];
    [properties setValue:[self getValueOfProperty:@"_id"] forKey:@"_id"];
    [properties setValue:[self getValueOfProperty:@"_rev"] forKey:@"_rev"];

    COUCHLOG2(@"%@ Saving <- %@", self, properties);
    self.needsSave = NO;
    RESTOperation* op = [_document putProperties: properties];
    [op onCompletion: ^{
        if (op.isSuccessful)
            [self detachFromDocument];
    }];
    [op start];
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
    NSSet* keys = [[self class] propertyNames];
    for (NSString* key in keys)
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
    for (NSString* key in keys)
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


- (void) setAutosaves: (bool) autosaves {
    if (autosaves != _autosaves) {
        _autosaves = autosaves;
        if (_autosaves && _needsSave)
            [self performSelector: @selector(save) withObject: nil afterDelay: 0.0];
    }
}


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


+ (RESTOperation*) saveModels: (NSArray*)models {
    CouchDatabase* db = nil;
    NSUInteger n = models.count;
    NSMutableArray* changes = [NSMutableArray arrayWithCapacity: n];
    NSMutableArray* changedModels = [NSMutableArray arrayWithCapacity: n];
    NSMutableArray* changedDocs = [NSMutableArray arrayWithCapacity: n];
    
    for (CouchModel* model in models) {
        if (!db)
            db = model.database;
        else
            NSAssert(model.database == db, @"Models must share a common db");
        if (!model.needsSave)
            continue;
        [changes addObject: model.propertiesToSave];
        [changedModels addObject: model];
        [changedDocs addObject: model.document];
        model.needsSave = NO;
    }
    if (changes.count == 0)
        return nil;
       
    RESTOperation* op = [db putChanges: changes toRevisions: changedDocs];
    [op onCompletion: ^{
        for (CouchModel* model in changedModels) {
            [model saveCompleted: op];
            // TODO: This doesn't handle the case where op succeeded but an individual doc failed
        }
    }];
    return op;
}


#pragma mark - PROPERTIES:

+ (NSSet*) propertyNames {
    if (self == [CouchModel class])
        return [NSSet set]; // Ignore non-persisted properties declared on base CouchModel
    return [super propertyNames];
}

// Transforms cached property values back into JSON-compatible objects
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
    if (!value && !self.isNew && ![_changedNames containsObject: property]) {
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

- (CouchDatabase*) databaseForModelProperty: (NSString*)property {
    // This is a hook for subclasses to override if they need to, i.e. if the property
    // refers to a document in a different database.
    return _document.database;
}

- (CouchModel*) getModelProperty: (NSString*)property {
    // Model-valued properties are kept in raw form as document IDs, not mapped to CouchModel
    // references, to avoid reference loops.
    
    // First get the target document ID:
    NSString* rawValue = [self getValueOfProperty: property];
    if (!rawValue)
        return nil;
    
    // Look up the CouchDocument:
    if (![rawValue isKindOfClass: [NSString class]]) {
        Warn(@"Model-valued property %@ of %@ is not a string", property, _document);
        return nil;
    }
    CouchDocument* doc = [[self databaseForModelProperty: property] documentWithID: rawValue];
    if (!doc) {
        Warn(@"Unable to get document from property %@ of %@ (value='%@')",
             property, _document, rawValue);
        return nil;
    }
    
    // Ask factory to get/create model; if it doesn't know, use the declared class:
    CouchModel* value = [doc.database.modelFactory modelForDocument: doc];
    if (!value) {
        Class declaredClass = [[self class] classOfProperty: property];
        value = [declaredClass modelForDocument: doc];
        if (!value) 
            Warn(@"Unable to instantiate %@ from %@ -- property %@ of %@ (%@)",
                 declaredClass, doc, property, self, _document);
    }
    return value;
}

- (void) setModel: (CouchModel*)model forProperty: (NSString*)property {
    // Don't store the target CouchModel in the _properties dictionary, because this could create
    // a reference loop. Instead, just store the raw document ID. getModelProperty will map to the
    // model object when called.
    NSString* docID = model.document.documentID;
    NSAssert(docID || !model, 
             @"Cannot assign untitled %@ as the value of model property %@.%@ -- save it first",
             model.document, [self class], property);
    [self setValue: docID ofProperty: property];
}


+ (IMP) impForGetterOfProperty: (NSString*)property ofClass: (Class)propertyClass {
    if (propertyClass == Nil || propertyClass == [NSString class]
             || propertyClass == [NSNumber class] || propertyClass == [NSArray class]
             || propertyClass == [NSDictionary class])
        return [super impForGetterOfProperty: property ofClass: propertyClass];  // Basic classes (including 'id')
    else if (propertyClass == [NSData class]) {
        return imp_implementationWithBlock(^id(CouchModel* receiver) {
            return [receiver getDataProperty: property];
        });
    } else if (propertyClass == [NSDate class]) {
        return imp_implementationWithBlock(^id(CouchModel* receiver) {
            return [receiver getDateProperty: property];
        });
    } else if ([propertyClass isSubclassOfClass: [CouchModel class]]) {
        return imp_implementationWithBlock(^id(CouchModel* receiver) {
            return [receiver getModelProperty: property];
        });
    } else {
        return NULL;  // Unsupported
    }
}

+ (IMP) impForSetterOfProperty: (NSString*)property ofClass: (Class)propertyClass {
    if ([propertyClass isSubclassOfClass: [CouchModel class]]) {
        return imp_implementationWithBlock(^(CouchModel* receiver, CouchModel* value) {
            [receiver setModel: value forProperty: property];
        });
    } else {
        return [super impForSetterOfProperty: property ofClass: propertyClass];
    }
}


#pragma mark - KVO:


// CouchDocuments (and transitively their models) have only weak references from the CouchDatabase,
// so they may be dealloced if not used in a while. This is very bad if they have any observers, as
// the observation reference will dangle and cause crashes or mysterious bugs.
// To work around this, turn observation into a string reference by doing a retain.
// This may result in reference cycles if two models observe each other; not sure what to do about
// that yet!

- (void) addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context {
    [super addObserver: observer forKeyPath: keyPath options: options context: context];
    if (observer != self)
        [self retain];
}

- (void) removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    [super removeObserver: observer forKeyPath: keyPath];
    if (observer != self)
        [self retain];
    [self release];
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
