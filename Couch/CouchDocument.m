//
//  CouchDocument.m
//  CouchCocoa
//
//  Created by Jens Alfke on 5/26/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CouchDocument.h"
#import "CouchInternal.h"


NSString* const kCouchDocumentChangeNotification = @"CouchDocumentChange";


@interface CouchDocument ()
@property (readwrite) BOOL isDeleted;
@end


@implementation CouchDocument


- (void)dealloc {
    if (_modelObject)
        Warn(@"Deallocing %@ while it still has a modelObject %@", self, _modelObject);
    [_currentRevisionID release];
    [_currentRevision release];
    [super dealloc];
}


- (NSString*) documentID {
    return self.relativePath;
}


#pragma mark REVISIONS:


@synthesize isDeleted=_isDeleted, modelObject=_modelObject;


- (NSString*) currentRevisionID {
    return _currentRevisionID;
}

- (void) setCurrentRevisionID:(NSString *)revisionID {
    NSParameterAssert(revisionID);
    if (![revisionID isEqualToString: _currentRevisionID]) {
        [_currentRevisionID autorelease];
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


- (void) loadCurrentRevisionFrom: (CouchQueryRow*)row {
    NSString* rev = row.documentRevision;
    if (rev) {
        if (!_currentRevisionID || [_currentRevisionID isEqualToString: rev]) {
            [self setCurrentRevisionID: rev];
            
            NSDictionary* properties = row.documentProperties;
            if (properties) {
                if (!_currentRevision)
                    _currentRevision = [[CouchRevision alloc] initWithDocument: self
                                                                    revisionID: rev];
                [_currentRevision setProperties:properties];
            }
        }
    }
}


- (NSArray*) getRevisionHistory {
    RESTOperation* op = [self sendHTTP: @"GET" 
                            parameters: [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"true", @"?revs_info", nil]];
    if (![op wait])
        return nil;
    NSArray* revs_info = $castIf(NSArray, 
                                 [op.responseBody.fromJSON objectForKey: @"_revs_info"]);
    NSMutableArray* revisions = [NSMutableArray arrayWithCapacity: revs_info.count];
    for (NSDictionary* item in revs_info) {
        if ([[item objectForKey: @"status"] isEqual: @"available"]) {
            NSString* revID = [item objectForKey: @"rev"];
            // Insert in reverse order, as CouchDB returns the current revision first:
            if (revID) {
                CouchRevision* rev = [self revisionWithID: revID];
                [revisions insertObject: rev atIndex: 0];
            }
        }
    }
    return revisions;
}


#pragma mark -
#pragma mark CONFLICTS:


- (NSArray*) getConflictingRevisions {
    // http://wiki.apache.org/couchdb/Replication_and_conflicts
    // Apparently open_revs isn't official API, and ?conflicts is preferred, but open_revs
    // has the advantage of returning the contents of all conflicting revisions at once.
    RESTOperation* op = [self sendHTTP: @"GET" 
                            parameters: [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"all", @"?open_revs",
                                         @"application/json", @"Accept",
                                         nil]];
    if (![op wait])
        return nil;
    NSArray* items = $castIf(NSArray, op.responseBody.fromJSON);
    if (!items)
        return nil;
    return [items rest_map: ^(id item) {
        NSDictionary* contents = $castIf(NSDictionary, [item objectForKey: @"ok"]);
        if (![[contents objectForKey: @"_deleted"] boolValue]) {
            NSString* revisionID = $castIf(NSString, [contents objectForKey: @"_rev"]);
            if (revisionID) {
                CouchRevision* revision = [self revisionWithID: revisionID];
                if (!revision.propertiesAreLoaded)
                    revision.properties = contents;
                return revision;
            }
        }
        return (id)nil;
    }];
}


- (RESTOperation*) resolveConflictingRevisions: (NSArray*)conflicts
                                withProperties: (NSDictionary*)properties
{
    NSParameterAssert(properties);
    NSAssert(_currentRevision, @"Don't know current revision?!");
    NSAssert([conflicts indexOfObjectIdenticalTo: _currentRevision] != NSNotFound,
             @"Conflict list doesn't include current revision");
    NSArray* changes = [conflicts rest_map: ^(id revision) {
        return (revision == _currentRevision) ? properties : [NSNull null];
    }];
    return [self.database putChanges: changes toRevisions: conflicts];
}


- (RESTOperation*) resolveConflictingRevisions: (NSArray*)conflicts 
                                  withRevision: (CouchRevision*)winningRevision
{
    return [self resolveConflictingRevisions: conflicts withProperties: winningRevision.properties];
}


#pragma mark PROPERTIES:


- (NSDictionary*) properties {
    return self.currentRevision.properties;
}

- (NSDictionary*) userProperties {
    return self.currentRevision.userProperties;
}

- (id) propertyForKey: (NSString*)key {
    return [self.currentRevision propertyForKey: key];
}


- (RESTOperation*) putProperties: (NSDictionary*)properties {
    NSParameterAssert(properties != nil);
    
    if (_currentRevisionID && ![properties objectForKey: @"_rev"]) {
        Warn(@"Trying to PUT to %@ without specifying a rev ID", self);
    }
    
    return [self PUTJSON: properties parameters: nil];
}


- (RESTOperation*) PUT: (NSData*)body
            parameters: (NSDictionary*)parameters
{
    RESTOperation* op = [super PUT: body parameters: parameters];
    if (op.isPOST)
        [self.database beginDocumentOperation: self];   // I'm being created via a POST
    return op;
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
    
    BOOL deleted = [[change objectForKey: @"deleted"] isEqual: (id)kCFBooleanTrue];

    COUCHLOG(@"**** CHANGE #%@: %@  %@ -> %@%@",
          [change objectForKey: @"seq"], self, _currentRevisionID, rev,
          (deleted ?@" DELETED" :@""));

    self.currentRevisionID = rev;

    if (deleted)
        self.isDeleted = YES;
    
    if ([_modelObject respondsToSelector: @selector(couchDocumentChanged:)])
        [_modelObject couchDocumentChanged: self];
    
    NSNotification* n = [NSNotification notificationWithName: kCouchDocumentChangeNotification
                                                      object: self
                                                    userInfo: change];
    [[NSNotificationCenter defaultCenter] postNotification: n];
    return YES;
}


#pragma mark -
#pragma mark OPERATION HANDLING:


- (RESTOperation*) sendRequest: (NSURLRequest*)request {
    RESTOperation* op = [super sendRequest: request];
    if (!op.isReadOnly)
        [self.database beginDocumentOperation: self];
    return op;
}


- (NSMutableURLRequest*) requestWithMethod: (NSString*)method
                                parameters: (NSDictionary*)parameters {
    if ([method isEqualToString: @"DELETE"]) {
        NSString* revision = _currentRevisionID;
        if (revision) {
            // Add a ?rev= query param with the current document revision:
            NSMutableDictionary* nuParams = [[parameters mutableCopy] autorelease];
            if (!nuParams)
                nuParams = [NSMutableDictionary dictionary];
            [nuParams setObject: revision forKey: @"?rev"];
            parameters = nuParams;
        } else {
            Warn(@"Trying to DELETE %@ without knowing its current rev ID", self);
        }
    }
    return [super requestWithMethod: method parameters: parameters];
}


- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error {
    error = [super operation: op willCompleteWithError: error];
    
    if (!error && op.httpStatus < 300) {
        // On a PUT or DELETE, update my current revision ID:
        if (op.isPUT || op.isDELETE) {
            NSString* rev = [op.responseBody.fromJSON objectForKey: @"rev"];
            self.currentRevisionID = rev;
            op.resultObject = self.currentRevision;
            if (op.isDELETE)
                self.isDeleted = YES;
        }
    } else if (op.httpStatus == 404 && op.isGET) {
        // Check whether it's been deleted:
        if ([[op.responseBody.fromJSON objectForKey: @"reason"] isEqualToString: @"deleted"])
            self.isDeleted = YES;
    }
    
    if (!op.isReadOnly)
        [self.database endDocumentOperation: self];

    return error;
}


- (void) updateFromSaveResponse: (NSDictionary*)response 
                 withProperties: (NSDictionary*)properties
{
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
    
    if (!rev) {
        Warn(@"No revision ID received for save response of %@", self);
        return;
    }
    
    self.currentRevisionID = rev;
    if (properties) {
        if (!_currentRevision)
            _currentRevision = [[CouchRevision alloc] initWithDocument: self
                                                            revisionID: rev];
        [_currentRevision setProperties:properties];
        if (_currentRevision.isDeleted)
            self.isDeleted = YES;
    }
}


- (void) createdByPOST: (RESTOperation*)op {
    [super createdByPOST: op];    //FIX: Should update relativePath directly from 'id' instead
    [self updateFromSaveResponse: $castIf(NSDictionary, op.responseBody.fromJSON)
                  withProperties: nil];
    [self.database documentAssignedID: self];
    [self.database endDocumentOperation: self];   // I was created via a POST
}


// Called by -[CouchDatabase putChanges:toRevisions:] after a successful save.
- (void) bulkSaveCompleted: (NSDictionary*) result forProperties: (NSDictionary*)properties {
    if (![result objectForKey: @"error"])
        [self updateFromSaveResponse: result withProperties: properties];
}


@end
