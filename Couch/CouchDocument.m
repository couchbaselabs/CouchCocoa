//
//  CouchDocument.m
//  CouchCocoa
//
//  Created by Jens Alfke on 5/26/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchDocument.h"
#import "CouchInternal.h"


@interface CouchDocument ()
@property (readwrite) BOOL isDeleted;
@end


@implementation CouchDocument


- (void)dealloc {
    [_currentRevisionID release];
    [_currentRevision release];
    [super dealloc];
}


- (NSString*) documentID {
    return self.relativePath;
}


#pragma mark REVISIONS:


@synthesize isDeleted=_isDeleted, currentRevisionID=_currentRevisionID;


- (void) setCurrentRevisionID:(NSString *)revisionID {
    if (![revisionID isEqualToString: _currentRevisionID]) {
        [_currentRevisionID release];
        _currentRevisionID = [revisionID copy];
        [_currentRevision autorelease];
        _currentRevision = nil;
    }
}


- (CouchRevision*) revisionWithID: (NSString*)revisionID {
    NSParameterAssert(revisionID);
    if ([revisionID isEqualToString: _currentRevisionID])
        return self.currentRevision;
    return [[[CouchRevision alloc] initWithDocument: self revisionID: revisionID] autorelease];
}


- (CouchRevision*) currentRevision {
    if (!_currentRevision) {
        if (_currentRevisionID)
            _currentRevision = [[CouchRevision alloc] initWithDocument: self
                                                            revisionID: _currentRevisionID];
        else if (self.relativePath)
            _currentRevision = [[CouchRevision alloc] initWithOperation: [self GET]];
    }
    return _currentRevision;
}


- (void) loadRevisionFrom: (NSDictionary*)contents {
    NSString* rev = $castIf(NSString, [contents objectForKey: @"_rev"]);
    if (rev) {
        if (!_currentRevisionID || [_currentRevisionID isEqualToString: rev]) {
            // OK, I can set the current revisions contents from the given dictionary:
            [self setCurrentRevisionID: rev];
            if (!_currentRevision)
                _currentRevision = [[CouchRevision alloc] initWithDocument: self
                                                                revisionID: rev];
            [_currentRevision setContents:contents];
        }
    }
}


- (NSArray*) getRevisionHistory {
    RESTOperation* op = [self sendHTTP: @"GET" 
                            parameters: [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"true", @"?revs", nil]];
    if (![op wait])
        return nil;
    NSDictionary* revisions = $castIf(NSDictionary, 
                                      [op.responseBody.fromJSON objectForKey: @"_revisions"]);
    NSArray* revIDs = [revisions objectForKey: @"ids"];
    int start = [$castIf(NSNumber, [revisions objectForKey: @"start"]) intValue];
    if (start < 1 || start < revIDs.count)
        return nil;
    NSMutableArray* revs = [NSMutableArray arrayWithCapacity: revIDs.count];
    for (NSString* revID in revIDs) {
        revID = [NSString stringWithFormat: @"%i-%@", start--, revID];
        // Server returns revs in reverse order, but I want to return them forwards
        [revs insertObject: [self revisionWithID: revID] atIndex: 0];
    }
    return revs;
}


#pragma mark PROPERTIES:


- (NSDictionary*) properties {
    return self.currentRevision.properties;
}


- (id) propertyForKey: (NSString*)key {
    return [self.currentRevision propertyForKey: key];
}


- (RESTOperation*) putProperties: (NSDictionary*)properties {
    NSParameterAssert(properties != nil);
    for (NSString* key in properties)
        NSAssert1(![key hasPrefix: @"_"], @"Illegal property key '%@'", key);
    
    if (_currentRevisionID) {
        NSMutableDictionary* newProperties = [[properties mutableCopy] autorelease];
        [newProperties setObject: _currentRevisionID forKey: @"_rev"];
        properties = newProperties;
    }
    
    return [self PUTJSON: properties parameters: nil];
}


#pragma mark -
#pragma mark CHANGES:


// Called by the database when the _changes feed reports this document's been changed
- (BOOL) notifyChanged: (NSDictionary*)change {
    // Get revision:
    NSArray* changeList = $castIf(NSArray, [change objectForKey: @"changes"]);
    NSDictionary* changeDict = $castIf(NSDictionary, changeList.lastObject);
    // TODO: Can there ever be more than one object in the list? What does that mean?
    NSString* rev = $castIf(NSString, [changeDict objectForKey: @"rev"]);
    if (!rev)
        return NO;
    
    if ([_currentRevisionID isEqualToString: rev])
        return NO;
    self.currentRevisionID = rev;

    if ([[change objectForKey: @"deleted"] isEqual: (id)kCFBooleanTrue])
        self.isDeleted = YES;
    
    NSNotification* n = [NSNotification notificationWithName: kCouchDocumentChangeNotification
                                                      object: self
                                                    userInfo: change];
    [[NSNotificationCenter defaultCenter] postNotification: n];
    return YES;
}


- (void) updateFromSaveResponse: (NSDictionary*)response {
    NSString* docID = [response objectForKey: @"id"];
    NSString* rev = [response objectForKey: @"rev"];
    
    // Sanity-check the document ID:
    NSString* myDocID = self.documentID;
    if (myDocID) {
        if (![docID isEqualToString: myDocID]) {
            Warn(@"Document ID mismatch: id='%@' for %@", docID, self);
            return;
        }
    } else {
        if (!docID) {
            Warn(@"No document ID received for saving untitled %@", self);
            return;
        }
    }
    
    self.currentRevisionID = rev;
}


#pragma mark -
#pragma mark OPERATION HANDLING:


- (NSMutableURLRequest*) requestWithMethod: (NSString*)method
                                parameters: (NSDictionary*)parameters {
    if ([method isEqualToString: @"DELETE"]) {
        NSString* revision = self.currentRevisionID;
        if (revision) {
            // Add a ?rev= query param with the current document revision:
            NSMutableDictionary* nuParams = [[parameters mutableCopy] autorelease];
            if (!nuParams)
                nuParams = [NSMutableDictionary dictionary];
            [nuParams setObject: revision forKey: @"?rev"];
            parameters = nuParams;
        }
    }
    return [super requestWithMethod: method parameters: parameters];
}


- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error {
    error = [super operation: op willCompleteWithError: error];
    
    if (op.httpStatus < 300) {
        // On a PUT or DELETE, update my current revision ID:
        if (op.isPUT || op.isDELETE) {
            NSString* rev = [op.responseBody.fromJSON objectForKey: @"rev"];
            self.currentRevisionID = rev;
            if (op.isDELETE)
                self.isDeleted = YES;
        }
    } else if (op.httpStatus == 404 && op.isGET) {
        // Check whether it's been deleted:
        if ([[op.responseBody.fromJSON objectForKey: @"reason"] isEqualToString: @"deleted"])
            self.isDeleted = YES;
    }
    return error;
}


- (void) createdByPOST: (RESTOperation*)op {
    [super createdByPOST: op];    //FIX: Should update relativePath directly from 'id' instead
    [self updateFromSaveResponse: $castIf(NSDictionary, op.responseBody.fromJSON)];
    [self.database documentAssignedID: self];
}


// Called by -[CouchDatabase putChanges:toRevisions:] after a successful save.
- (void) bulkSaveCompleted: (NSDictionary*) result {
    if (![result objectForKey: @"error"])
        [self updateFromSaveResponse: result];
}


@end
