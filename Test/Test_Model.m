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
@property (readwrite, retain) NSArray* otherNames;
@property (readwrite, retain) TestModel* buddy;
@end

@implementation TestModel
@dynamic name, grade, permanentRecord, birthday, otherNames, buddy;
@end


@interface Test_Model : CouchTestCase
- (TestModel*) createModelWithName: (NSString*)name grade: (int)grade;
- (NSData*) attachmentData;
@end


@implementation Test_Model


- (void) test0_propertyNames {
    NSSet* names = [NSSet setWithObjects: @"name", @"grade", @"permanentRecord", @"birthday", @"otherNames", @"buddy", nil];
    STAssertEqualObjects([TestModel propertyNames], names, nil);
}


- (void) test1_read {
    NSData* permanentRecord = [@"ACK PTHBBBT" dataUsingEncoding: NSUTF8StringEncoding];
    CFAbsoluteTime time = floor(CFAbsoluteTimeGetCurrent()); // no fractional seconds
    NSDate* birthday = [NSDate dateWithTimeIntervalSinceReferenceDate: time];
    NSArray *otherNames = [NSArray arrayWithObjects:@"Bob", @"Robert", nil];
    NSDictionary* props = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Bobby Tables", @"name",
                           [NSNumber numberWithInt: 6], @"grade",
                           [RESTBody base64WithData: permanentRecord], @"permanentRecord",
                           [RESTBody JSONObjectWithDate: birthday], @"birthday",
                           otherNames, @"otherNames",
                           nil];
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
    STAssertEqualObjects(student.otherNames, otherNames, nil);
    STAssertEqualObjects(student.buddy, nil, nil);
}


- (void) test2_write {
    TestModel* student = [self createModelWithName: @"Bobby Tables" grade: 6];
    CouchDocument* doc = student.document;
    
    NSData* permanentRecord = [@"ACK PTHBBBT" dataUsingEncoding: NSUTF8StringEncoding];
    CFAbsoluteTime time = floor(CFAbsoluteTimeGetCurrent()); // no fractional seconds
    NSDate* birthday = [NSDate dateWithTimeIntervalSinceReferenceDate: time];
    student.permanentRecord = permanentRecord;
    student.birthday = birthday;
    STAssertEqualObjects(student.permanentRecord, permanentRecord, nil);
    STAssertEqualObjects(student.birthday, birthday, nil);
    NSArray *otherNames = [NSArray arrayWithObjects:@"Bob", @"Robert", nil];
    student.otherNames = otherNames;
    STAssertEqualObjects(student.otherNames, otherNames, nil);
    
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
    STAssertEqualObjects(student2.otherNames, otherNames, nil);
}


// Tests adding an attachment to a new document before saving.
- (void) test3_newAttachment {
    TestModel* student = [self createModelWithName: @"Pippi Langstrumpf" grade: 4];
    CouchDocument* doc = student.document;

    [student createAttachmentWithName: @"mugshot" type: @"image/png" body: self.attachmentData];
    
    AssertWait([student save]);
    NSString* docID = student.document.documentID;
    STAssertNotNil(docID, nil);
    
    // Forget all CouchDocuments!
    [_db clearDocumentCache];
    
    CouchDocument *doc2 = [_db documentWithID: docID];
    STAssertFalse(doc2 == doc, @"Doc was cached when it shouldn't have been");
    TestModel* student2 = [TestModel modelForDocument: doc2];
    STAssertFalse(student2 == student, @"Model was cached when it shouldn't have been");
    
    STAssertEqualObjects(student2.attachmentNames, [NSArray arrayWithObject: @"mugshot"], nil);
    CouchAttachment* attach = [student2 attachmentNamed: @"mugshot"];
    STAssertEqualObjects(attach.name, @"mugshot", nil);
    STAssertEqualObjects(attach.contentType, @"image/png", nil);
    STAssertEqualObjects(attach.body, self.attachmentData, nil);
}


// Tests adding an attachment to an existing already-saved document.
- (void) test4_addAttachment {
    TestModel* student = [self createModelWithName: @"Pippi Langstrumpf" grade: 4];
    CouchDocument* doc = student.document;
    
    AssertWait([student save]);
    
    [student createAttachmentWithName: @"mugshot" type: @"image/png" body: self.attachmentData];

    STAssertEqualObjects(student.attachmentNames, [NSArray arrayWithObject: @"mugshot"], nil);
    CouchAttachment* attach = [student attachmentNamed: @"mugshot"];
    STAssertEqualObjects(attach.name, @"mugshot", nil);
    STAssertEqualObjects(attach.contentType, @"image/png", nil);
    STAssertEqualObjects(attach.body, self.attachmentData, nil);
    
    AssertWait([student save]);

    STAssertEqualObjects(student.attachmentNames, [NSArray arrayWithObject: @"mugshot"], nil);
    attach = [student attachmentNamed: @"mugshot"];
    STAssertEqualObjects(attach.name, @"mugshot", nil);
    STAssertEqualObjects(attach.contentType, @"image/png", nil);
    STAssertEqualObjects(attach.body, self.attachmentData, nil);
    
    // Forget all CouchDocuments!
    NSString* docID = student.document.documentID;
    STAssertNotNil(docID, nil);
    [_db clearDocumentCache];
    
    CouchDocument *doc2 = [_db documentWithID: docID];
    STAssertFalse(doc2 == doc, @"Doc was cached when it shouldn't have been");
    TestModel* student2 = [TestModel modelForDocument: doc2];
    STAssertFalse(student2 == student, @"Model was cached when it shouldn't have been");
    
    STAssertEqualObjects(student2.attachmentNames, [NSArray arrayWithObject: @"mugshot"], nil);
    attach = [student2 attachmentNamed: @"mugshot"];
    STAssertEqualObjects(attach.name, @"mugshot", nil);
    STAssertEqualObjects(attach.contentType, @"image/png", nil);
    STAssertEqualObjects(attach.body, self.attachmentData, nil);
}


- (void) test5_relationships {
    {
        CouchDocument* doc1 = [_db documentWithID: @"0001"];
        TestModel* tweedledum = [TestModel modelForDocument: doc1];
        tweedledum.name = @"Tweedledum";
        tweedledum.grade = 2;

        CouchDocument* doc2 = [_db documentWithID: @"0002"];
        TestModel* tweedledee = [TestModel modelForDocument: doc2];
        tweedledee.name = @"Tweedledee";
        tweedledee.grade = 2;
        
        tweedledum.buddy = tweedledee;
        STAssertEquals(tweedledum.buddy, tweedledee, nil);
        tweedledee.buddy = tweedledum;
        STAssertEquals(tweedledee.buddy, tweedledum, nil);
        
        AssertWait([tweedledum save]);
        AssertWait([tweedledee save]);
    }
    
    // Forget all CouchDocuments!
    [_db clearDocumentCache];

    {
        CouchDocument* doc1 = [_db documentWithID: @"0001"];
        TestModel* tweedledum = [TestModel modelForDocument: doc1];
        STAssertEqualObjects(tweedledum.name, @"Tweedledum", nil);
        
        TestModel* tweedledee = tweedledum.buddy;
        STAssertNotNil(tweedledee, nil);
        STAssertEqualObjects(tweedledee.document.documentID, @"0002", nil);
        STAssertEqualObjects(tweedledee.name, @"Tweedledee", nil);
        STAssertEquals(tweedledee.buddy, tweedledum, nil);
    }
}


- (void) test6_bulkSave {
    NSString* id1;
    {
        TestModel* m1 = [self createModelWithName: @"Alice" grade: 9];
        TestModel* m2 = [self createModelWithName: @"Bartholomew" grade: 10];
        TestModel* m3 = [self createModelWithName: @"Claire" grade: 11];
        
        RESTOperation* op = [CouchModel saveModels: [NSArray arrayWithObjects: m1, m2, m3, nil]];
        AssertWait(op);
        
        STAssertFalse(m1.needsSave, nil);
        STAssertFalse(m2.needsSave, nil);
        STAssertFalse(m3.needsSave, nil);
        
        id1 = m1.document.documentID;
        STAssertNotNil(id1, nil);
        STAssertTrue([m1.document.currentRevisionID hasPrefix: @"1-"], nil);
    }
    [_db clearDocumentCache];
    
    TestModel* m1 = [TestModel modelForDocument: [_db documentWithID: id1]];
    STAssertEqualObjects(m1.name, @"Alice", nil);
}

- (void) test6_deleteWithAdditionalProperties {
    
    TestModel* m1 = [self createModelWithName: @"Alice" grade: 9];
    AssertWait([m1 save]);
    TestModel* m2 = [self createModelWithName: @"Bob" grade: 9];
    AssertWait([m2 save]);

    NSString *m2DocumentID = [[m2 document] propertyForKey:@"_id"];

    AssertWait([m1 deleteDocumentWithAdditionalProperties:nil]);
    STAssertTrue(([m1 document] == nil), @"Model's document should be nil after being deleted");

    AssertWait([m2 deleteDocumentWithAdditionalProperties:@{@"foo":@"bar"}]);
    STAssertTrue(([m2 document] == nil), @"Model's document should be nil after being deleted");

    CouchDocument *deletedDocument = [_db documentWithID:m2DocumentID];
    STAssertTrue([deletedDocument propertyForKey:@"_deleted"] == [NSNumber numberWithBool:TRUE], @"expected _deleted property to be true");
    STAssertTrue([[deletedDocument propertyForKey:@"foo"] isEqualToString:@"bar"], @"expected foo property to be set");
    // STAssertTrue([deletedDocument isDeleted], @"Document should be deleted");  <-- why isn't [document isDeleted] true?  bug?
   
}


#pragma mark - UTILITIES:

- (TestModel*) createModelWithName: (NSString*)name grade: (int)grade {
    CouchDocument* doc = [_db untitledDocument];
    TestModel* student = [TestModel modelForDocument: doc];
    STAssertNil(student.name, nil);
    STAssertEquals(student.grade, 0, nil);
    STAssertNil(student.permanentRecord, nil, nil);
    STAssertNil(student.birthday, nil, nil);
    student.name = name;
    student.grade = grade;
    STAssertEqualObjects(student.name, name, nil);
    STAssertEquals(student.grade, grade, nil);
    return student;
}


- (NSData*) attachmentData {
    NSString* path = [[NSBundle bundleForClass: [self class]] pathForResource: @"logo" ofType:@"png"];
    STAssertNotNil(path, @"Couldn't get Logo.png resource for attachment test");
    return [NSData dataWithContentsOfFile: path];
}


@end
