//
//  Test_REST.m
//  Test REST
//
//  Created by Jens Alfke on 6/10/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "RESTResource.h"
#import "RESTBody.h"
#import "RESTInternal.h"

#import <SenTestingKit/SenTestingKit.h>


// HTTP resources to test GETs of. These assume a CouchDB server is running on localhost. */
static NSString* const kParentURL = @"http://127.0.0.1:5984/_utils";
static NSString* const kChildPath = @"image/logo.png";
static NSString* const kChildURL = @"http://127.0.0.1:5984/_utils/image/logo.png";


@interface Test_REST : SenTestCase
@end


@implementation Test_REST

- (void)setUp
{
    [super setUp];
    
    gRESTWarnRaisesException = YES;
    gRESTLogLevel = kRESTLogRequestHeaders;
}

- (void)tearDown
{
    gRESTLogLevel = kRESTLogNothing;
    [super tearDown];
}

- (void)testBasicGet
{
    // Test a root resource:
    NSURL* url = [NSURL URLWithString: kParentURL];
    RESTResource* parent = [[[RESTResource alloc] initWithURL: url] autorelease];
    STAssertEqualObjects(parent.URL, url, @"Server URL property is wrong");
    STAssertEqualObjects(parent.parent, nil, @"Server parent property is wrong");
    STAssertEqualObjects(parent.relativePath, nil, @"Server relativePath property is wrong");
    
    // Test child resource:
    RESTResource* child = [[[RESTResource alloc] initWithParent: parent relativePath: kChildPath] autorelease];
    STAssertEqualObjects(child.parent, parent, @"Child parent property is wrong");
    STAssertEqualObjects(child.relativePath, kChildPath, @"Child relativePath property is wrong");
    STAssertEqualObjects(child.URL, [NSURL URLWithString: kChildURL], nil);

    // Test GET:
    parent.tracksActiveOperations = YES;
    child.tracksActiveOperations = YES;
    RESTOperation* op = [child GET];
    STAssertNotNil(op, @"Failed to create RESTOperation");
    NSLog(@"Created %@:\n%@", op, op.dump);
    __block BOOL completeBlockCalled = NO;
    [op onCompletion: ^{ completeBlockCalled = YES; NSLog(@"Oncompletion!!"); }];
    
    STAssertEqualObjects(parent.activeOperations, [NSSet setWithObject: op], nil);
    STAssertEqualObjects(child.activeOperations, [NSSet setWithObject: op], nil);

    NSLog(@"About to wait...");
    STAssertTrue([op wait], @"Failed to GET: %@", op.error);
    NSLog(@"Got it: %@\n%@", op, op.dump);
    STAssertTrue(completeBlockCalled, @"onComplete block was not called");
    
    // Test caching:
    STAssertTrue([child cacheResponse: op], @"Should be cacheable");
    NSLog(@"ETag = %@, lastModified = %@", child.eTag, child.lastModified);
    //STAssertNotNil(child.eTag, @"Failed to get eTag");
    STAssertNotNil(child.lastModified, @"Failed to get lastModified");

    STAssertEquals(parent.activeOperations.count, (NSUInteger)0, nil);
    STAssertEquals(child.activeOperations.count, (NSUInteger)0, nil);
}

- (void)testMultipleWait {
    NSURL* url = [NSURL URLWithString: kParentURL];
    RESTResource* parent = [[[RESTResource alloc] initWithURL: url] autorelease];
    parent.tracksActiveOperations = YES;
    for (int i=0; i<5; i++)
        [[parent GET] start];
    NSSet* activeOps = [[parent.activeOperations copy] autorelease];
    STAssertEquals(activeOps.count, (NSUInteger)5, nil);
    
    [RESTOperation wait: parent.activeOperations];
    STAssertEquals(parent.activeOperations.count, (NSUInteger)0, nil);
    
    for (RESTOperation* op in activeOps) {
        STAssertTrue(op.isComplete, nil);
        STAssertNil(op.error, nil);
    }
}

- (void) testRetry {
    NSURL* url = [NSURL URLWithString: @"http://127.0.0.1:3"];
    RESTResource* resource = [[[RESTResource alloc] initWithURL: url] autorelease];
    RESTOperation* op = [resource GET];
    STAssertFalse([op wait], nil);
    STAssertTrue(op.retryCount > 0, nil);
}

- (void) testEntityHeaders {
    NSDictionary* headers = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"FooServ", @"Server",
                             @"image/jpeg", @"Content-Type",
                             @"abcdefg", @"Etag", nil];
    NSDictionary* expectedEntityHeaders = [NSDictionary dictionaryWithObjectsAndKeys:
                                           @"image/jpeg", @"Content-Type",
                                           @"abcdefg", @"Etag", nil];
    NSDictionary* emptyHeaders = [NSDictionary dictionary];
    
    STAssertEqualObjects([RESTBody entityHeadersFrom: headers], expectedEntityHeaders, nil);
    STAssertEqualObjects([RESTBody entityHeadersFrom: expectedEntityHeaders], expectedEntityHeaders, nil);
    
    STAssertEqualObjects([RESTBody entityHeadersFrom: emptyHeaders], emptyHeaders, nil);
    
    headers = [NSDictionary dictionaryWithObjectsAndKeys:
               @"FooServ", @"Server", nil];
    STAssertEqualObjects([RESTBody entityHeadersFrom: headers], emptyHeaders, nil);
}

- (void) testEmptyBody {
    RESTBody* body = [[RESTBody alloc] init];
    STAssertEqualObjects(body.content, [NSData data], nil);
    STAssertEqualObjects(body.headers, [NSDictionary dictionary], nil);
    STAssertEqualObjects(body.contentType, nil, nil);
    STAssertEqualObjects(body.eTag, nil, nil);
    STAssertEqualObjects(body.lastModified, nil, nil);
    [body release];
}

- (void) testEmptyMutableBody {
    RESTMutableBody* body = [[RESTMutableBody alloc] init];
    STAssertEqualObjects(body.content, [NSData data], nil);
    STAssertEqualObjects(body.headers, [NSDictionary dictionary], nil);
    STAssertEqualObjects(body.contentType, nil, nil);
    STAssertEqualObjects(body.eTag, nil, nil);
    STAssertEqualObjects(body.lastModified, nil, nil);
    [body release];
}

- (void) testMutateEmptyBody {
    RESTMutableBody* body = [[RESTMutableBody alloc] init];
    NSData* data = [@"foo" dataUsingEncoding: NSUTF8StringEncoding];
    body.content = data;
    body.contentType = @"text/plain; charset=utf-8";
    STAssertEqualObjects(body.content, data, nil);
    STAssertEqualObjects(body.headers, [NSDictionary dictionaryWithObject: @"text/plain; charset=utf-8" forKey: @"Content-Type"], nil);
    STAssertEqualObjects(body.contentType, @"text/plain; charset=utf-8", nil);
    [body release];
}

- (void) testBase64 {
    NSData* input = [@"this is the original string" dataUsingEncoding: NSUTF8StringEncoding];
    NSString* base64 = [RESTBody base64WithData: input];
    STAssertEqualObjects(base64, @"dGhpcyBpcyB0aGUgb3JpZ2luYWwgc3RyaW5n", nil);
    
    NSData* output = [RESTBody dataWithBase64: base64];
    STAssertEqualObjects(output, input, @"Base64 decoding failed");
    
    STAssertNil([RESTBody base64WithData: nil], @"Base64 encoding failed on nil input");
    STAssertNil([RESTBody dataWithBase64: nil], @"Base64 decoding failed on nil input");
}

@end
