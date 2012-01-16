//
//  CouchModelFactory.h
//  CouchCocoa
//
//  Created by Jens Alfke on 11/22/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class CouchDocument;


/** A configurable mapping from CouchDocument to CouchModel.
    It associates a model class with a value of the document's "type" property. */
@interface CouchModelFactory : NSObject
{
    NSMutableDictionary* _typeDict;
}

/** Returns the global shared CouchModelFactory. */
+ (CouchModelFactory*) sharedInstance;

/** Given a document, attempts to return a CouchModel for it.
    If the document's modelObject property is set, it returns that value.
    If the document's "type" property has been registered, instantiates the associated class.
    Otherwise returns nil. */
- (id) modelForDocument: (CouchDocument*)document;

/** Associates a value of the "type" property with a CouchModel subclass.
    @param classOrName  Either a CouchModel subclass, or its class name as an NSString.
    @param type  The value value of a document's "type" property that should indicate this class. */
- (void) registerClass: (id)classOrName forDocumentType: (NSString*)type;

/** Looks up the CouchModel subclass that's been registered for a document type. */
- (Class) classForDocumentType: (NSString*)type;

@end
