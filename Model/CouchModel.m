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


@interface CouchModel ()
@property (readwrite, retain) CouchDocument* document;
@property (readwrite) bool needsSave;
@property (readwrite) bool isEmbedded;
@property (readwrite, copy) NSString* referenceID;
- (NSDictionary*) attachmentDataToSave;
- (id) modelForDocument:(CouchDocument*)document property:(NSString *)property embed:(BOOL)embed;
- (void) reset;
@end


@implementation CouchModel

- (BOOL) setDefault: (id)value ofProperty: (NSString*)property {
    id current = [self getValueOfProperty:property];
    if (current == nil) 
        return [self setValue:value ofProperty:property];
    return NO;
}


- (void)ensureDefaults {
    _needsSave = [self setDefaultValues];
}


- (id)init {
    CouchModel* model = [self initWithDocument: nil];
    [model ensureDefaults];
    return model;
}


- (id) initWithDocument: (CouchDocument*)document {
    self = [super init];
    if (self) {
        if (document) {
            COUCHLOG2(@"%@ initWithDocument: %@ @%p", self, document, document);
            self.document = document;
            [self ensureDefaults];
            [self didLoadFromDocument];
        } else {
            COUCHLOG2(@"%@ init", self);
            [self setDefaultValues];
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
    if (self.isEmbedded) {
        NSString* ref = (self.document.abbreviatedID ? self.document.abbreviatedID : @"embedded");
        return [NSString stringWithFormat: @"%@<%@>", self.class, ref];
    } else {
        NSString* ref = (self.document.abbreviatedID ? self.document.abbreviatedID : @"untitled");
        return [NSString stringWithFormat: @"%@[%@]", self.class, ref];    
    }
}


#pragma mark - DOCUMENT / DATABASE:


- (BOOL) load {
    if (!self.document.currentRevision) { // not loaded yet, but attempt to
        [self couchDocumentChanged: self.document];
        [self ensureDefaults];
        [self didLoadFromDocument];
        return YES;
    }
    return NO;
}


- (BOOL) exists {
    return self.document.exists;
}


- (void) reset {
    _properties = nil;
    _changedNames = nil;
    _changedAttachments = nil;
    [self.document resetCurrentRevision];
    _needsSave = NO;
}


- (BOOL) reload {
    [self reset];
    return [self load];
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

- (BOOL) setDefaultValues {
    // subclasses can override this
    return NO; // return YES to mark for saving
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


@synthesize autosaves=_autosaves, needsSave=_needsSave;

- (bool) isNew {
    return !(_document && _document.currentRevisionID) || self.isEmbedded;
}  

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
        NSMutableDictionary* lookup = [NSMutableDictionary dictionary];
        NSArray* results = $castIf(NSArray, op.responseBody.fromJSON);
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSDictionary* result = $castIf(NSDictionary, obj);
            if (result) [lookup setObject:result forKey:[result valueForKey:@"id"]];
        }];
        
        for (CouchModel* model in changedModels) {
            NSDictionary* result = [lookup objectForKey:model.document.documentID];
            if (result && ![result objectForKey:@"error"]) {
                [model saveCompleted: op];
            }
        }
    }];
    return op;
}

#pragma mark - CREATING MODEL PROPERTY INSTANCES:

- (id) modelForDocument:(CouchDocument*)document property:(NSString *)property embed:(BOOL)embed {
    CouchModel* model = nil;
    if (embed && [self isEmbedableModelProperty:property]) {
        model = [CouchModel embeddedModelForDocument:document parent:self property:property];
    }
    if (!model) model = [CouchModel modelForDocument:document];  
    if (!model) {
        Class declaredClass = [[self class] classOfProperty: property];
        model = [declaredClass modelForDocument: document];
    }
    return model;
}

- (id) createModelForProperty:(NSString *)property {
    CouchDocument* doc = [[self databaseForModelProperty: property] untitledDocument];
    return [self modelForDocument:doc property:property embed:NO];
}

#pragma mark - EMBEDDED MODELS;

@synthesize isEmbedded=_isEmbedded, referenceID=_referenceID;

+ (id) embeddedModelForDocument:(CouchDocument *)document parent:(CouchModel*)parent property:(NSString *)property {
    return [CouchModel modelForDocument:document];
}

- (id) embedModelForProperty:(NSString *)property {
    CouchModel* model = [self createModelForProperty:property];
    if ([self embedModel:model forProperty:property]) return model;
    return nil;
}

- (BOOL) embedModel:(CouchModel*)model forProperty:(NSString *)property {
    if ([self isEmbedableModel:model forProperty:property]) {
        [model setIsEmbedded:YES];
        [model setReferenceID:model.document.documentID];
        [model didEmbedIn:self forProperty:property];
        [self setValue:model ofProperty:property];
        return YES;
    }
    return NO;
}

- (BOOL) isEmbedableModel:(CouchModel*)model forProperty:(NSString *)property {
    Class propertyClass = [self.class classOfProperty:property];
    return  [model isKindOfClass:propertyClass] &&
            [self isEmbedableModelProperty:property] && 
            [model isEmbedableIn:self forProperty:property];
}

- (BOOL) isEmbedableModelProperty: (NSString*)property {
    // This is a hook for embeddable subclasses to override if they need to.
    return YES; // defaults to YES.
}

- (BOOL) isEmbedableIn: (CouchModel*)parent forProperty:(NSString*)property {
    // This is a hook for embeddable subclasses to override if they need to.
    return YES; // defaults to YES.
}

- (void) didEmbedIn: (CouchModel*)parent forProperty:(NSString*)property {
    // This is a hook for embeddable subclasses to override if they need to.
}

- (BOOL) isEmbeddedModelProperty: (NSString*)property {
    CouchModel* model = [self getValueOfProperty:property];
    if ([model isKindOfClass:[CouchModel class]]) {
        return [model isEmbedded];
    }
    return NO;
}

#pragma mark - PROPERTIES:

+ (NSSet*) propertyNames {
    if (self == [CouchModel class])
        return [NSSet set]; // Ignore non-persisted properties declared on base CouchModel
    return [super propertyNames];
}

+ (NSSet*) writablePropertyNames {
    if (self == [CouchModel class])
        return [NSSet set]; // Ignore non-persisted properties declared on base CouchModel
    return [super writablePropertyNames];
}

- (NSDictionary*) properties {
    NSMutableDictionary* props = [NSMutableDictionary dictionary];
    [[self.class propertyNames] enumerateObjectsUsingBlock:^(id key, BOOL *stop) {
        id value = [self getValueOfProperty:key];
        [props setValue:value forKey:key];
    }];
    return props;
}

- (void) setProperties:(NSDictionary*)properties {
    [self resetProperties];
    [self updateProperties:properties strict:NO];
}

- (void) updateProperties:(NSDictionary*)properties {
    [self updateProperties:properties strict:YES];
}

- (void) clearProperties {
    _properties = nil;
    [self setDefaultValues];
}

- (void) resetProperties {
    [[self.class writablePropertyNames] enumerateObjectsUsingBlock:^(id key, BOOL *stop) {
        [self setValue:nil ofProperty:key];
    }];
    [self setDefaultValues];
}

// Transforms cached property values back into JSON-compatible objects
- (id) externalizePropertyValue: (id)value {
    if ([value isKindOfClass: [NSData class]])
        value = [RESTBody base64WithData: value];
    else if ([value isKindOfClass: [NSDate class]])
        value = [RESTBody JSONObjectWithDate: value];
    else if ([value isKindOfClass: [NSURL class]])
        value = [RESTBody JSONObjectWithURL: value];
    return value;
}


- (NSDictionary*) propertiesToSave {
    NSMutableDictionary* properties = [_document.properties mutableCopy];
    if (!properties)
        properties = [[NSMutableDictionary alloc] init];
    for (NSString* key in _changedNames) {
        id value = [self getValueOfProperty: key];
        if ([value isKindOfClass: [CouchModel class]] && (CouchModel*)[value isEmbedded]) {
            CouchModel* model = (CouchModel*)value;
            [properties setValue:[model propertiesToSave] forKey: key];
        } else {
            [properties setValue: [self externalizePropertyValue: value] forKey: key];
        }
    }
    if (self.isEmbedded) {
        if (self.referenceID) [properties setObject:self.referenceID forKey:@"_ref"];
    } else {
        [properties setValue: self.attachmentDataToSave forKey: @"_attachments"];
    }
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

- (NSURL*) getURLProperty: (NSString*)property {
    NSURL* value = [_properties objectForKey: property];
    if (!value) {
        id rawValue = [_document propertyForKey: property];
        if ([rawValue isKindOfClass: [NSString class]])
            value = [RESTBody urlWithJSONObject: rawValue];
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
    // references, to avoid reference loops. Embedded Objects are allowed.
    
    id rawValue = [self getValueOfProperty: property];
    if (!rawValue) return nil;
    
    if ([self isEmbeddedModelProperty:property]) {
        return rawValue;
    } else if ([rawValue isKindOfClass: [NSString class]]) {
        CouchDocument* doc = [[self databaseForModelProperty: property] documentWithID: rawValue];
        if (!doc) {
            Warn(@"Unable to get document from property %@ of %@ (value='%@')",
                 property, _document, rawValue);
            return nil;
        }
        
        // Ask factory to get/create model; if it doesn't know, use the declared class:
        CouchModel* model = [doc.database.modelFactory modelForDocument: doc];
        if (!model) {
            Class declaredClass = [[self class] classOfProperty: property];
            model = [declaredClass modelForDocument: doc];
            if (!model) 
                Warn(@"Unable to instantiate %@ from %@ -- property %@ of %@ (%@)",
                     declaredClass, doc, property, self, _document);
        }
        return model;
    } else if ([self isEmbedableModelProperty:property] && 
               [rawValue isKindOfClass: [NSDictionary class]]) {
        CouchModel* model = [self embedModelForProperty:property];
        model.referenceID = [rawValue valueForKey:@"_ref"];
        [model updateProperties:rawValue strict:NO];
        [model didEmbedIn:self forProperty:property];
        return model;
    } else {
        Warn(@"Model-valued property %@ of %@ is not a string or embedded dictionary", property, _document);
        return nil;
    }
}

- (void) setModel: (CouchModel*)model forProperty: (NSString*)property {
    if ([self isEmbeddedModelProperty: property]) {
        [self setValue: model ofProperty: property];
    } else {
        // Don't store the target CouchModel in the _properties dictionary, because this could create
        // a reference loop. Instead, just store the raw document ID. getModelProperty will map to the
        // model object when called.
        NSString* docID = model.document.documentID;
        NSAssert(docID || !model, 
                 @"Cannot assign untitled %@ as the value of model property %@.%@ -- save it first",
                 model.document, [self class], property);
        [self setValue: docID ofProperty: property];
    }
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

static id getURLProperty(CouchModel *self, SEL _cmd) {
    return [self getURLProperty: getterKey(_cmd)];
}

static id getModelProperty(CouchModel *self, SEL _cmd) {
    return [self getModelProperty: getterKey(_cmd)];
}

static void setModelProperty(CouchModel *self, SEL _cmd, id value) {
    return [self setModel: value forProperty: [CouchDynamicObject setterKey: _cmd]];
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
    else if (propertyClass == [NSURL class])
        return (IMP)getURLProperty;
    else if ([propertyClass isSubclassOfClass: [CouchModel class]])
        return (IMP)getModelProperty;
    else 
        return NULL;  // Unsupported
}

+ (IMP) impForSetterOfClass: (Class)propertyClass {
    if ([propertyClass isSubclassOfClass: [CouchModel class]])
        return (IMP)setModelProperty;
    else 
        return [super impForSetterOfClass: propertyClass];
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
