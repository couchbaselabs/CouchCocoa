//
//  CouchRevision.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/28/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CouchRevision.h"

#import "CouchInternal.h"


@implementation CouchRevision


- (id) initWithDocument: (CouchDocument*)document revisionID: (NSString*)revisionID {
    NSParameterAssert(document);
    if (revisionID)
        return [super initWithParent: document 
                        relativePath: [@"?rev=" stringByAppendingString: revisionID]];
    else
        return [super initUntitledWithParent: document];
}


- (id) initWithDocument: (CouchDocument*)document properties: (NSDictionary*)properties {
    NSParameterAssert(document);
    NSParameterAssert(properties);
    NSString* revisionID = $castIf(NSString, [properties objectForKey: @"_rev"]);
    if (!revisionID) {
        [self release];
        return nil;
    }
    
    self = [self initWithDocument: document revisionID: revisionID];
    if (self) {
        [self setProperties: properties];
    }
    return self;
}


- (id) initWithOperation: (RESTOperation*)operation {
    NSParameterAssert(operation.isGET);
    // Have to block to find out the revision ID. :(
    BOOL isDeleted = NO;
    if (![operation wait]) {
        // Check whether it's been deleted:
        if (operation.httpStatus == 404 && 
            [[operation.responseBody.fromJSON objectForKey: @"reason"] isEqualToString: @"deleted"]) {
            isDeleted = YES;
        } else {
            if (operation.httpStatus != 404)
                Warn(@"CouchRevision initWithOperation failed: %@ on %@", operation.error, operation);
            [self release];
            return nil;
        }
    }
    self = [self initWithDocument: $castIf(CouchDocument, operation.resource)
                         properties: operation.responseBody.fromJSON];
    if (self) {
        _isDeleted = isDeleted;
    }
    return self;
}


- (id) initWithParent: (RESTResource*)parent relativePath: (NSString*)relativePath {
    NSAssert(NO, @"Wrong initializer for CouchRevision");
    return nil;
}


- (void)dealloc {
    [_properties release];
    [super dealloc];
}


- (NSURL*) URL {
    if (!self.relativePath)
        return self.parent.URL;
    // My relativePath is a query string, not a path component
    NSString* urlStr = self.parent.URL.absoluteString;
    urlStr = [urlStr stringByAppendingString: self.relativePath];
    return [NSURL URLWithString: urlStr];
}


- (CouchDocument*) document {
    return (CouchDocument*) self.parent;
}


- (NSString*) documentID {
    return self.parent.relativePath;
}


- (BOOL) isCurrent {
    return [self.revisionID isEqualToString: self.document.currentRevisionID];
}


@synthesize isDeleted=_isDeleted;


- (NSString*) revisionID {
    return [self.relativePath substringFromIndex: 5];
}


#pragma mark -
#pragma mark CONTENTS / PROPERTIES:


- (BOOL) propertiesAreLoaded {
    return _properties != nil;
}


- (NSDictionary*) properties {
    if (!_properties) {
        [[self GET] wait];   // synchronous!
    }
    return _properties;
}


- (void) setProperties: (NSDictionary*)properties {
    if (properties != _properties) {
        [_properties release];
        _properties = [properties copy];
        _isDeleted = [$castIf(NSNumber, [properties objectForKey: @"_deleted"]) boolValue];
    }
}


- (NSDictionary*) userProperties {
    NSDictionary* rep = [self properties];
    if (!rep)
        return nil;
    NSMutableDictionary* props = [NSMutableDictionary dictionary];
    for (NSString* key in rep) {
        if (![key hasPrefix: @"_"])
            [props setObject: [rep objectForKey: key] forKey: key];
    }
    return props;
}


- (id) propertyForKey: (NSString*)key {
    return [self.properties objectForKey: key];
}


- (RESTOperation*) putProperties: (NSDictionary*)properties {
    NSParameterAssert(properties != nil);
    NSMutableDictionary* contents = [[properties mutableCopy] autorelease];
    [contents setObject: self.documentID forKey: @"_id"];
    [contents setObject: self.revisionID forKey: @"_rev"];
    
    RESTOperation* op = [self PUTJSON: contents parameters: nil];
    [op onCompletion: ^{
        if (op.isSuccessful) {
            // Construct a new revision object from the response and assign it to the resultObject:
            NSString* rev = $castIf(NSString, [op.responseBody.fromJSON objectForKey: @"rev"]);
            if (rev) {
                [contents setObject: rev forKey: @"_rev"];
                CouchRevision* savedRev = [[CouchRevision alloc] initWithDocument: self.document
                                                                       properties: contents];
                op.resultObject = savedRev;
                [savedRev release];
            }
        }
    }];
    return op;
}


- (RESTOperation*) sendRequest: (NSURLRequest*)request {
    RESTOperation* op = [super sendRequest: request];
    if (!op.isReadOnly)
        [self.database beginDocumentOperation: self];
    return op;
}


- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error {
    error = [super operation: op willCompleteWithError: error];
    if (op.isSuccessful && !error) {
        if (op.isGET) {
            // Cache document properties after GET:
            self.properties = op.responseBody.fromJSON;
        } else if (op.isPUT) {
            // Tell the document about the new revision ID:
            NSString* rev = $castIf(NSString, [op.responseBody.fromJSON objectForKey: @"rev"]);
            if (rev)
                [self.document setCurrentRevisionID: rev];
        }
    }

    if (!op.isReadOnly)
        [self.database endDocumentOperation: self];
    
    return error;
}


#pragma mark -
#pragma mark ATTACHMENTS:


- (NSDictionary*) attachmentMetadata {
    return $castIf(NSDictionary, [self.properties objectForKey: @"_attachments"]);
}


- (NSDictionary*) attachmentMetadataFor: (NSString*)name {
    return $castIf(NSDictionary, [self.attachmentMetadata objectForKey: name]);
}


- (NSArray*) attachmentNames {
    return [self.attachmentMetadata allKeys];
}


- (CouchAttachment*) attachmentNamed: (NSString*)name {
    NSDictionary* metadata = [self attachmentMetadataFor: name];
    NSString* type = $castIf(NSString, [metadata objectForKey: @"content_type"]);
    if (!type)
        return nil;
    return [[[CouchAttachment alloc] initWithRevision: self name: name type: type] autorelease];
}


- (CouchAttachment*) createAttachmentWithName: (NSString*)name type: (NSString*)contentType {
    return [[[CouchAttachment alloc] initWithRevision: self name: name type: contentType]
                autorelease];
}


@end
