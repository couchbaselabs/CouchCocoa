//
//  Test_DynamicObject.m
//  CouchCocoa
//
//  Created by Jens Alfke on 8/27/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchDynamicObject.h"
#import "CouchInternal.h"
#import <SenTestingKit/SenTestingKit.h>


@interface TestDynamicObject : CouchDynamicObject
{
    @public
    NSMutableDictionary* _dict;
}
- (id) initWithDictionary: (NSDictionary*)dict;
@property (readwrite,copy) NSString *stringy;
@property (readonly) int intey;
@property (readwrite) short shorty;
@property (readwrite) double doubley;
@property (readwrite) bool booley;
@end

@implementation TestDynamicObject

- (id) initWithDictionary: (NSDictionary*)dict {
    self = [super init];
    if (self) {_dict = [dict mutableCopy];}
    return self;
}

- (void)dealloc {
    [_dict release];
    [super dealloc];
}

- (id) getValueOfProperty: (NSString*)property {
    return [_dict objectForKey: property];
}

- (BOOL) setValue: (id)value ofProperty: (NSString*)property {
    [_dict setValue: value forKey: property];
    return YES;
}

@dynamic stringy, intey, shorty, doubley, booley;

@end


@interface TestDynamicSubclass : TestDynamicObject
@property (copy) NSData* dataey;
@end

@implementation TestDynamicSubclass
@dynamic dataey;
@end


@interface Test_DynamicObject : SenTestCase
@end


@implementation Test_DynamicObject


- (void) test0_Subclass {
    // It's important to run this test first, before the accessor methods are created for
    // TestDynamicObject by the other tests, because this one ensure the methods get attached to
    // the appropriate class in the hierarchy.
    //gCouchLogLevel = 2;
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"String value", @"stringy",
                          [NSNumber numberWithInt: -6789], @"intey",
                          [NSData data], @"dataey", nil];
    TestDynamicSubclass *test = [[TestDynamicSubclass alloc] initWithDictionary: dict];
    STAssertEqualObjects(test.stringy, @"String value", nil);
    STAssertEquals(test.intey, -6789, nil);
    STAssertEquals(test.doubley, 0.0, nil);
    STAssertEqualObjects(test.dataey, [NSData data], nil);
    
    test.stringy = nil;
    STAssertEqualObjects(test.stringy, nil, nil);
    test.doubley = 123.456;
    STAssertEquals(test.doubley, 123.456, nil);
    test.booley = true;
    STAssertEquals(test.booley, (bool)true, nil);
    test.dataey = nil;
    STAssertEqualObjects(test.dataey, nil, nil);
}


- (void) test1_EmptyDynamicObject {
    TestDynamicObject *test = [[TestDynamicObject alloc] initWithDictionary: 
                                    [NSDictionary dictionary]];
    STAssertTrue([test respondsToSelector: @selector(setStringy:)], nil);
    STAssertFalse([test respondsToSelector: @selector(setIntey:)], nil);
    STAssertFalse([test respondsToSelector: @selector(dataey)], nil);
    STAssertFalse([test respondsToSelector: @selector(size)], nil);
    STAssertEqualObjects(test.stringy, nil, nil);
    STAssertEquals(test.intey, 0, nil);
    STAssertEquals(test.doubley, 0.0, nil);
    STAssertEquals(test.booley, (bool)false, nil);
    [test release];
}


- (void) test2_DynamicObject {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"String value", @"stringy",
                          [NSNumber numberWithInt: -6789], @"intey", nil];
    TestDynamicObject *test = [[TestDynamicObject alloc] initWithDictionary: dict];
    STAssertEqualObjects(test.stringy, @"String value", nil);
    STAssertEquals(test.intey, -6789, nil);
    STAssertEquals(test.doubley, 0.0, nil);
    
    test.stringy = nil;
    STAssertEqualObjects(test.stringy, nil, nil);
    test.doubley = 123.456;
    STAssertEquals(test.doubley, 123.456, nil);
    test.booley = true;
    STAssertEquals(test.booley, (bool)true, nil);
    
    NSDictionary* expected = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithBool: YES], @"booley",
                              [NSNumber numberWithDouble: 123.456], @"doubley",
                              [NSNumber numberWithInt: -6789], @"intey", nil];
    STAssertEqualObjects(test->_dict, expected, nil);
    [test release];
}


- (void) test3_intTypes {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithShort: -6789], @"shorty", nil];
    TestDynamicObject *test = [[TestDynamicObject alloc] initWithDictionary: dict];
    STAssertEquals(test.shorty, (short)-6789, nil);
    test.shorty = 32767;
    STAssertEquals(test.shorty, (short)32767, nil);
    STAssertEqualObjects([test->_dict objectForKey: @"shorty"], [NSNumber numberWithShort: 32767], nil);
    test.shorty = -32768;
    STAssertEquals(test.shorty, (short)-32768, nil);
    STAssertEqualObjects([test->_dict objectForKey: @"shorty"], [NSNumber numberWithShort: -32768], nil);
}


@end
