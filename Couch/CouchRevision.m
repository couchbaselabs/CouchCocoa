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
        self.representedObject = [[contents copy] autorelease];
        _isDeleted = [$castIf(NSNumber, [contents objectForKey: @"_deleted"]) boolValue];
    }
    return self;
}


- (id) initWithOperation: (RESTOperation*)operation {
    NSParameterAssert(operation);
    // Have to block to find out the revision ID. :(
    BOOL isDeleted = NO;
    if (![operation wait]) {
        // Check whether it's been deleted:
        if (operation.httpStatus == 404 && 
            [[operation representedValueForKey: @"reason"] isEqualToString: @"deleted"]) {
            isDeleted = YES;
        } else {       
            Warn(@"CouchRevision initWithOperation failed: %@ on %@", operation.error, operation);
            [self release];
            return nil;
        }
    }
    self = [self initWithDocument: $castIf(CouchDocument, operation.resource)
                         contents: operation.representedObject];
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


- (NSDictionary*) fromJSON {
    NSDictionary* json = self.representedObject;
    if (!json) {
        [[self GET] wait];   // synchronous!
        json = self.representedObject;
    }
    return json;
}


- (NSDictionary*) properties {
    if (!_properties) {
        NSDictionary* rep = [self fromJSON];
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
    return [self.fromJSON objectForKey: key];
}


- (RESTOperation*) putProperties: (NSDictionary*)properties {
    NSParameterAssert(properties != nil);
    for (NSString* key in properties)
        NSAssert1(![key hasPrefix: @"_"], @"Illegal property key '%@'", key);
    
    return [self PUTJSON: properties parameters: nil];
}


#pragma mark -
#pragma mark ATTACHMENTS:


- (NSDictionary*) attachmentMetadata {
    return $castIf(NSDictionary, [self.fromJSON objectForKey: @"_attachments"]);
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
    return [[[CouchAttachment alloc] initWithDocument: self.document name: name type: type] autorelease];
}


- (CouchAttachment*) createAttachmentWithName: (NSString*)name type: (NSString*)contentType {
    if ([self attachmentMetadataFor: name])
        return nil;
    return [[[CouchAttachment alloc] initWithDocument: self.document name: name type: contentType] autorelease];
}


@end
