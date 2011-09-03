//
//  Test_Model.m
//  CouchCocoa
//
//  Created by Jens Alfke on 8/27/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchDynamicObject.h"
#import "CouchInternal.h"
#import "CouchTestCase.h"


@interface TestModel : CouchModel
@property (readwrite,copy) NSString *name;
@property (readwrite) int grade;
@property (readwrite, retain) NSData* permanentRecord;
@property (readwrite, retain) NSDate* birthday;
@end

@implementation TestModel
@dynamic name, grade, permanentRecord, birthday;
@end


@interface Test_Model : CouchTestCase
@end


@implementation Test_Model


- (void) test1_read {
    NSData* permanentRecord = [@"ACK PTHBBBT" dataUsingEncoding: NSUTF8StringEncoding];
    CFAbsoluteTime time = floor(CFAbsoluteTimeGetCurrent()); // no fractional seconds
    NSDate* birthday = [NSDate dateWithTimeIntervalSinceReferenceDate: time];
    NSDictionary* props = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Bobby Tables", @"name",
                           [NSNumber numberWithInt: 6], @"grade",
                           [RESTBody base64WithData: permanentRecord], @"permanentRecord",
                           [RESTBody JSONObjectWithDate: birthday], @"birthday", nil];
    CouchDocument* doc = [_db untitledDocument];
    AssertWait([doc putProperties: props]);
    
    TestModel* student = [TestModel modelForDocument: doc];
    STAssertNotNil(student, nil);
    STAssertEquals(student.document, doc, nil);
    STAssertEquals([TestModel modelForDocument: doc], student, nil);
    
    STAssertEqualObjects(student.name, @"Bobby Tables", nil);
    STAssertEquals(student.grade, 6, nil);
    STAssertEqualObjects(student.permanentRecord, permanentRecord, nil);
    STAssertEqualObjects(student.birthday, birthday, nil);
}


- (void) test2_write {
    CouchDocument* doc = [_db untitledDocument];
    TestModel* student = [TestModel modelForDocument: doc];
    STAssertNil(student.name, nil);
    STAssertEquals(student.grade, 0, nil);
    STAssertNil(student.permanentRecord, nil, nil);
    STAssertNil(student.birthday, nil, nil);
    
    NSData* permanentRecord = [@"ACK PTHBBBT" dataUsingEncoding: NSUTF8StringEncoding];
    CFAbsoluteTime time = floor(CFAbsoluteTimeGetCurrent()); // no fractional seconds
    NSDate* birthday = [NSDate dateWithTimeIntervalSinceReferenceDate: time];

    student.name = @"Bobby Tables";
    student.grade = 6;
    student.permanentRecord = permanentRecord;
    student.birthday = birthday;

    STAssertEqualObjects(student.name, @"Bobby Tables", nil);
    STAssertEquals(student.grade, 6, nil);
    STAssertEqualObjects(student.permanentRecord, permanentRecord, nil);
    STAssertEqualObjects(student.birthday, birthday, nil);
    
    AssertWait([student save]);
    NSString* docID = student.document.documentID;
    STAssertNotNil(docID, nil);
    
    // Forget all CouchDocuments!
    [_db clearDocumentCache];
    
    CouchDocument *doc2 = [_db documentWithID: docID];
    STAssertFalse(doc2 == doc, @"Doc was cached when it shouldn't have been");
    TestModel* student2 = [TestModel modelForDocument: doc2];
    STAssertFalse(student2 == student, @"Model was cached when it shouldn't have been");
    
    STAssertEqualObjects(student2.name, @"Bobby Tables", nil);
    STAssertEquals(student2.grade, 6, nil);
    STAssertEqualObjects(student2.permanentRecord, permanentRecord, nil);
    STAssertEqualObjects(student2.birthday, birthday, nil);
}


@end
