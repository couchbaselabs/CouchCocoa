//
//  CouchModel.h
//  CouchCocoa
//
//  Created by Jens Alfke on 8/26/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchDynamicObject.h"
@class CouchAttachment, CouchDatabase, CouchDocument, RESTOperation;


/** Generic model class for Couch documents.
    There's a 1::1 mapping between these and CouchDocuments; call +modelForDocument: to get (or create) a model object for a document, and .document to get the document of a model.
    You should subclass this and declare properties in the subclass's @interface. As with NSManagedObject, you don't need to implement their accessor methods or declare instance variables; simply note them as '@dynamic' in the @implementation. The property value will automatically be fetched from or stored to the document, using the same name.
    Supported scalar types are bool, char, short, int, double. These map to JSON numbers, except 'bool' which maps to JSON 'true' and 'false'. (Use bool instead of BOOL.)
    Supported object types are NSString, NSNumber, NSData, NSDate, NSArray, NSDictionary. (NSData and NSDate are not native JSON; they will be automatically converted to/from strings in base64 and ISO date formats, respectively.)
    Additionally, a property's type can be a pointer to a CouchModel subclass. This provides references between model objects. The raw property value in the document must be a string whose value is interpreted as a document ID. */
@interface CouchModel : CouchDynamicObject
{
    @private
    CouchDocument* _document;
    CFAbsoluteTime _changedTime;
    bool _autosaves :1;
    bool _isNew     :1;
    bool _needsSave :1;

    NSMutableDictionary* _properties;   // Cached property values, including changed values
    NSMutableSet* _changedNames;        // Names of properties that have been changed but not saved
    NSMutableDictionary* _changedAttachments;
}

/** Returns the CouchModel associated with a CouchDocument, or creates & assigns one if necessary.
    Don't call this on CouchModel itself, rather on the subclass you want to instantiate for that document, e.g. [MyWidgetModel modelForDocument: doc]. It always returns an instance of the class it's called on. */
+ (id) modelForDocument: (CouchDocument*)document;

/** Creates a new "untitled" model with a new unsaved document.
    The document won't be written to the database until -save is called. */
- (id) initWithNewDocumentInDatabase: (CouchDatabase*)database;

/** Creates a new "untitled" model object with no document or database at all yet.
    Setting its .database property will cause it to create a CouchDocument.
    (This method is mostly here so that NSController objects can create CouchModels.) */
- (id) init;

/** The document this item is associated with. Will be nil if it's new and unsaved. */
@property (readonly, retain) CouchDocument* document;

/** The database the item's document belongs to.
    Setting this property will assign the item to a database, creating a document.
    Setting it to nil will delete its document from its database. */
@property (retain) CouchDatabase* database;

/** Is this model new, never before saved? */
@property (readonly) bool isNew;

#pragma mark - SAVING:

/** Writes any changes to a new revision of the document, asynchronously.
    Does nothing and returns nil if no changes have been made. */
- (RESTOperation*) save;

/** Should changes be saved back to the database automatically?
    Defaults to NO, requiring you to call -save manually. */
@property (nonatomic) bool autosaves;

/** Does this model have unsaved changes? */
@property (readonly) bool needsSave;

/** The document's current properties, in externalized JSON format. */
- (NSDictionary*) propertiesToSave;

/** Deletes the document from the database. 
    You can still use the model object afterwards, but it will refer to the deleted revision. */
- (RESTOperation*) deleteDocument;

/** The time interval since the document was last changed externally (e.g. by a "pull" replication.
    This value can be used to highlight recently-changed objects in the UI. */
@property (readonly) NSTimeInterval timeSinceExternallyChanged;

/** Bulk-saves changes to multiple model objects (which must all be in the same database).
    This invokes -[CouchDatabase putChanges:], which sends a single request to _bulk_docs.
    Any unchanged models in the array are ignored.
    @param models  An array of CouchModel objects, which must all be in the same database.
    @return  A RESTOperation that saves all changes, or nil if none of the models need saving. */
+ (RESTOperation*) saveModels: (NSArray*)models;

/** Resets the timeSinceExternallyChanged property to zero. */
- (void) markExternallyChanged;

#pragma mark - PROPERTIES & ATTACHMENTS:

/** Gets a property by name.
    You can use this for document properties that you haven't added @property declarations for. */
- (id) getValueOfProperty: (NSString*)property;

/** Sets a property by name.
    You can use this for document properties that you haven't added @property declarations for. */
- (BOOL) setValue: (id)value ofProperty: (NSString*)property;


/** The names of all attachments (array of strings).
    This reflects unsaved changes made by creating or deleting attachments. */
@property (readonly) NSArray* attachmentNames;

/** Looks up the attachment with the given name (without fetching its contents). */
- (CouchAttachment*) attachmentNamed: (NSString*)name;

/** Creates or updates an attachment (in memory).
    The attachment data will be written to the database at the same time as property changes are saved.
    @param name  The attachment name.
    @param contentType  The MIME type of the body.
    @param body  The raw attachment data, or nil to delete the attachment. */
- (CouchAttachment*) createAttachmentWithName: (NSString*)name
                                         type: (NSString*)contentType
                                         body: (NSData*)body;

/** Deletes (in memory) any existing attachment with the given name.
    The attachment will be deleted from the database at the same time as property changes are saved. */
- (void) removeAttachmentNamed: (NSString*)name;



#pragma mark - PROTECTED (FOR SUBCLASSES TO OVERRIDE)

/** Designated initializer. Do not call directly except from subclass initializers; to create a new instance call +modelForDocument: instead.
    @param document  The document. Nil if this is created new (-init was called). */
- (id) initWithDocument: (CouchDocument*)document;

/** The document ID to use when creating a new document.
    Default is nil, which means to assign no ID (the server will assign one). */
- (NSString*) idForNewDocumentInDatabase: (CouchDatabase*)db;

/** Called when the model's properties are reloaded from the document.
    This happens both when initialized from a document, and after an external change. */
- (void) didLoadFromDocument;

@end
