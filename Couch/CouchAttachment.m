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


@interface CouchAttachment ()
@property (readwrite, copy) NSString* contentType;
@end


@implementation CouchAttachment


- (id) initWithRevision: (CouchRevision*)revision 
                   name: (NSString*)name
                   type: (NSString*)contentType
{
    NSParameterAssert(contentType);
    self = [super initWithParent: revision relativePath: name];
    if (self) {
        _contentType = [contentType copy];
    }
    return self;
}


- (void)dealloc {
    [_contentType release];
    [super dealloc];
}


@synthesize contentType = _contentType;


- (NSString*) name {
    return self.relativePath;
}


- (CouchRevision*) revision {
    return (CouchRevision*)self.parent;
}


- (CouchDocument*) document {
    return (CouchDocument*)self.parent.parent;
}


- (NSURL*) unversionedURL  {
    return [self.document.URL URLByAppendingPathComponent: self.name];
}


#pragma mark -
#pragma mark BODY


- (RESTOperation*) PUT: (NSData*)body contentType: (NSString*)contentType {
    if (!contentType) {
        contentType = _contentType;
        NSParameterAssert(contentType != nil);
    }
    NSDictionary* params = [NSDictionary dictionaryWithObject: contentType
                                                       forKey: @"Content-Type"];
    return [self PUT: body parameters: params];
}


- (RESTOperation*) PUT: (NSData*)body {
    return [self PUT: body contentType: _contentType];
}


- (NSData*) body {
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
        // Capture changes to the contentType made by GETs and PUTs:
        if (op.isGET)
            self.contentType = [op.responseHeaders objectForKey: @"Content-Type"];
        else if (op.isPUT) {
            self.contentType = [op.request valueForHTTPHeaderField: @"Content-Type"];
            NSString* revisionID = $castIf(NSString, [op.responseBody.fromJSON objectForKey: @"rev"]);
            if (revisionID)
                self.document.currentRevisionID = revisionID;
        }
    }
    return error;
}


@end
