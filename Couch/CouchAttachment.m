//
//  CouchAttachment.m
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

#import "CouchAttachment.h"
#import "CouchInternal.h"


@implementation CouchAttachment


- (id) initWithParent: (CouchResource*)parent 
                 name: (NSString*)name
             metadata: (NSDictionary*)metadata
{
    NSParameterAssert(metadata);
    self = [super initWithParent: parent relativePath: name];
    if (self) {
        _metadata = [metadata copy];
    }
    return self;
}


- (void)dealloc {
    [_metadata release];
    [super dealloc];
}


@synthesize metadata=_metadata;


- (NSString*) name {
    return self.relativePath;
}


- (CouchRevision*) revision {
    id parent = self.parent;
    if ([parent isKindOfClass: [CouchRevision class]])
        return parent;
    else
        return nil;
}


- (CouchDocument*) document {
    RESTResource* parent = self.parent;
    if ([parent isKindOfClass: [CouchRevision class]])
        parent = [parent parent];
    return (CouchDocument*)parent;
}


- (NSURL*) unversionedURL  {
    return [self.document.URL URLByAppendingPathComponent: self.name];
}


- (NSString*) contentType {
    return $castIf(NSString, [_metadata objectForKey: @"content_type"]);
}


- (UInt64) length {
    NSNumber* lengthObj = $castIf(NSNumber, [_metadata objectForKey: @"length"]);
    return lengthObj ? [lengthObj longLongValue] : 0;
}


#pragma mark -
#pragma mark BODY


- (RESTOperation*) PUT: (NSData*)body contentType: (NSString*)contentType {
    NSDictionary* params = [NSDictionary dictionaryWithObject: contentType
                                                       forKey: @"Content-Type"];
    return [self PUT: body parameters: params];
}


- (RESTOperation*) PUT: (NSData*)body {
    return [self PUT: body contentType: self.contentType];
}


- (NSData*) body {
    NSData* body = [RESTBody dataWithBase64: $castIf(NSString, [_metadata objectForKey: @"data"])];
    if (body)
        return body;
    
    RESTOperation* op = [self GET];
    if ([op wait])
        return op.responseBody.content;
    else {
        Warn(@"Synchronous CouchAttachment.body getter failed: %@", op.error);
        return nil;
    }
}


- (void) setBody: (NSData*)body {
    RESTOperation* op = [self PUT: body];
    if (![op wait])
        Warn(@"Synchronous CouchAttachment.body setter failed: %@", op.error);
}

/*
- (NSMutableURLRequest*) requestWithMethod: (NSString*)method
                                parameters: (NSDictionary*)parameters {
    if ([method isEqualToString: @"PUT"] || [method isEqualToString: @"DELETE"]) {
        // Add a ?rev= query param with the current document revision:
        NSString* revisionID = self.revision.revisionID;
        if (revisionID) {
            NSMutableDictionary* nuParams = [[parameters mutableCopy] autorelease];
            if (!nuParams)
                nuParams = [NSMutableDictionary dictionary];
            [nuParams setObject: revisionID forKey: @"?rev"];
            parameters = nuParams;
        }
    }
    return [super requestWithMethod: method parameters: parameters];
}
*/

- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error {
    error = [super operation: op willCompleteWithError: error];
    
    if (!error && op.isSuccessful) {
        if (op.isPUT) {
            NSString* revisionID = $castIf(NSString, [op.responseBody.fromJSON objectForKey: @"rev"]);
            if (revisionID)
                self.document.currentRevisionID = revisionID;
        }
    }
    return error;
}


@end
