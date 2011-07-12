//
//  CouchRevision.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/28/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

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


- (id) initWithDocument: (CouchDocument*)document contents: (NSDictionary*)contents {
    NSParameterAssert(document);
    NSParameterAssert(contents);
    NSString* revisionID = $castIf(NSString, [contents objectForKey: @"_rev"]);
    if (!revisionID) {
        [self release];
        return nil;
    }
    
    self = [self initWithDocument: document revisionID: revisionID];
    if (self) {
        _contents = [contents copy];
        _isDeleted = [$castIf(NSNumber, [contents objectForKey: @"_deleted"]) boolValue];
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
            Warn(@"CouchRevision initWithOperation failed: %@ on %@", operation.error, operation);
            [self release];
            return nil;
        }
    }
    self = [self initWithDocument: $castIf(CouchDocument, operation.resource)
                         contents: operation.responseBody.fromJSON];
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


- (BOOL) contentsAreLoaded {
    return _contents != nil;
}


- (NSDictionary*) contents {
    if (!_contents) {
        [[self GET] wait];   // synchronous!
    }
    return _contents;
}


- (void) setContents: (NSDictionary*)contents {
    if (contents != _contents) {
        [_contents release];
        _contents = [contents copy];
    }
}


- (NSDictionary*) properties {
    if (!_properties) {
        NSDictionary* rep = [self contents];
        if (rep) {
            NSMutableDictionary* props = [[NSMutableDictionary alloc] init];
            for (NSString* key in rep) {
                if (![key hasPrefix: @"_"])
                    [props setObject: [rep objectForKey: key] forKey: key];
            }
            _properties = [props copy];
            [props release];
        }
    }
    return _properties;
}


- (id) propertyForKey: (NSString*)key {
    if ([key hasPrefix: @"_"])
        return nil;
    return [self.contents objectForKey: key];
}


- (RESTOperation*) putProperties: (NSDictionary*)properties {
    NSParameterAssert(properties != nil);
    for (NSString* key in properties)
        NSAssert1(![key hasPrefix: @"_"], @"Illegal property key '%@'", key);
    
    NSMutableDictionary* contents = [[properties mutableCopy] autorelease];
    [contents setObject: self.documentID forKey: @"_id"];
    [contents setObject: self.revisionID forKey: @"_rev"];
    
    RESTOperation* op = [self PUTJSON: contents parameters: nil];
    [op onCompletion: ^{
        if (op.isSuccessful) {
            // Construct a new revision object from the response and assign it to the resultObject:
            NSString* rev = $castIf(NSString, [op.responseBody.fromJSON objectForKey: @"rev"]);
            if (rev) {
                // Also tell the document about the new revision ID:
                [self.document setCurrentRevisionID: rev];
                [contents setObject: rev forKey: @"_rev"];
                CouchRevision* savedRev = [[CouchRevision alloc] initWithDocument: self.document
                                                                         contents: contents];
                op.resultObject = savedRev;
                [savedRev release];
            }
        }
    }];
    return op;
}


- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error {
    error = [super operation: op willCompleteWithError: error];
    if (op.isGET && op.isSuccessful) {
        // Cache document contents after GET:
        self.contents = op.responseBody.fromJSON;
    }
    return error;
}


#pragma mark -
#pragma mark ATTACHMENTS:


- (NSDictionary*) attachmentMetadata {
    return $castIf(NSDictionary, [self.contents objectForKey: @"_attachments"]);
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
    if ([self attachmentMetadataFor: name])
        return nil;
    return [[[CouchAttachment alloc] initWithRevision: self name: name type: contentType] autorelease];
}


@end
