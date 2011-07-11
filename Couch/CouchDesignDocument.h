//
//  CouchDesignDocument.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/8/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchDocument.h"
@class CouchQuery;


/** Language parameter for JavaScript map and reduce functions. */
extern NSString* const kCouchLanguageJavaScript;


/** A C structure used to package up the definition of a view.
    All the fields are autoreleased, so you don't need to retain or release them. */
typedef struct CouchViewDefinition {
    NSString* mapFunction;      /**< The source code of the map function. Never nil. */
    NSString* reduceFunction;   /**< The source code of the reduce function, or nil if none. */
    NSString* language;         /**< Programming language; defaults to kCouchLanguageJavaScript. */
} CouchViewDefinition;


/** A Design Document is a special document type that contains things like map/reduce functions, and the code and static resources for CouchApps. */
@interface CouchDesignDocument : CouchDocument
{
    @private
    NSMutableDictionary* _views;
    BOOL _changed;
}

/** Creates a query for the given named view. */
- (CouchQuery*) queryViewNamed: (NSString*)viewName;

/** Fetches and returns the names of all the views defined in this design document.
    The first call fetches the entire design document synchronously; subsequent calls are cached. */
@property (readonly) NSArray* viewNames;

/** Fetches the map and/or reduce functions defining the given named view.
    If there is no view by that name, the "mapFunction" field of the result will be nil.
    The first call fetches the entire design document synchronously; subsequent calls are cached. */
- (CouchViewDefinition) getViewNamed: (NSString*)viewName;

/** Creates, updates or deletes a view given map and/or reduce functions.
    Does not send the changes to the server until you call -saveChanges.
    @param definition  Pointer to the view definition, or NULL to delete the view.
    @param viewName  The name of the view. */
- (BOOL) setDefinition: (const CouchViewDefinition*)definition
           ofViewNamed: (NSString*)viewName;

/** Have the contents of the design document been changed in-memory but not yet saved? */
@property (readonly) BOOL changed;

/** Saves changes, asynchronously. If there are no current changes, returns nil. */
- (RESTOperation*) saveChanges;

@end
