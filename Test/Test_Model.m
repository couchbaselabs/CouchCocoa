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

@interface TestModelSubclass : TestModel
@property (readonly) NSString* type;
@property (readwrite, retain) NSString* status;
@end

@implementation TestModelSubclass
@dynamic type, status;
- (void)setDefaultValues {
    [self setValue:@"test-model" ofProperty:@"type"];
    [self setValue:@"inactive" ofProperty:@"status"];
    [self setValue:[NSArray array] ofProperty:@"otherNames"];
}
@end

@interface Test_Model : CouchTestCase
- (TestModel*) createModelWithName: (NSString*)name grade: (int)grade;
- (NSData*) attachmentData;
@end

@implementation Test_Model


- (void) test0_propertyNames {
    NSSet* names = [NSSet setWithObjects: @"name", @"grade", @"permanentRecord", @"birthday", @"otherNames", @"buddy", nil];
    STAssertEqualObjects([TestModel propertyNames], names, nil);
    NSSet* allNames = [NSSet setWithObjects: @"name", @"grade", @"permanentRecord", @"birthday", @"otherNames", @"buddy", @"type", @"status", nil];
    STAssertEqualObjects([TestModelSubclass propertyNames], allNames, nil);
    STAssertEqualObjects([TestModelSubclass writablePropertyNames], [names setByAddingObject:@"status"], nil);
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
    
    STAssertTrue(student.isNew, nil);
    
    AssertWait([student save]);
    NSString* docID = student.document.documentID;
    STAssertFalse(student.isNew, nil);
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


- (void) test7_setDefaultValues {
    NSString* docID;
    NSArray* otherNames = [NSArray arrayWithObjects:@"Alicia", @"Ali", nil];
    {
        CouchDocument* doc = [_db untitledDocument];
        TestModelSubclass* student = [TestModelSubclass modelForDocument: doc];
        
        STAssertEqualObjects(student.type, @"test-model", nil);
        STAssertEqualObjects([student.properties objectForKey:@"type"], @"test-model", nil);
        STAssertEqualObjects([student.propertiesToSave objectForKey:@"type"], @"test-model", nil);
        
        STAssertEqualObjects(student.status, @"inactive", nil);
        STAssertEqualObjects([student.properties objectForKey:@"status"], @"inactive", nil);
        STAssertEqualObjects([student.propertiesToSave objectForKey:@"status"], @"inactive", nil);
        
        STAssertEqualObjects(student.otherNames, [NSArray array], nil);
        STAssertEqualObjects([student.properties objectForKey:@"otherNames"], [NSArray array], nil);
        STAssertEqualObjects([student.propertiesToSave objectForKey:@"otherNames"], [NSArray array], nil);
        
        STAssertFalse(student.needsSave, nil); // stock object, with all the defaults
        
        student.status = @"active";
        
        STAssertTrue(student.needsSave, nil); // stock object, with all the defaults
        
        student.otherNames = otherNames;
        STAssertEqualObjects(student.otherNames, otherNames, nil);
        
        STAssertEqualObjects(student.status, @"active", nil);
        STAssertEqualObjects([student.propertiesToSave objectForKey:@"status"], @"active", nil);
        STAssertEqualObjects([student.propertiesToSave objectForKey:@"otherNames"], otherNames, nil);
        
        STAssertTrue(student.isNew, nil);
        
        RESTOperation* op = [student save];
        AssertWait(op);
        docID = student.document.documentID;
    }
    [_db clearDocumentCache];
    
    TestModelSubclass* student = [TestModelSubclass modelForDocument: [_db documentWithID: docID]];
    STAssertFalse(student.isNew, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"active", nil);
    STAssertEqualObjects([student.propertiesToSave objectForKey:@"status"], @"active", nil);
    STAssertEqualObjects([student.propertiesToSave objectForKey:@"otherNames"], otherNames, nil);
}

- (void) test9_setDefaultValues {
    {
        CouchDocument* doc = [_db documentWithID: @"0001"];
        TestModelSubclass* student = [TestModelSubclass modelForDocument: doc];
        STAssertTrue(student.isNew, nil);
        student.name = @"Tweedledum";
        student.grade = 2;
        
        STAssertTrue(student.isNew, nil);
        STAssertEqualObjects(student.type, @"test-model", nil);
        STAssertEqualObjects(student.status, @"inactive", nil);
        
        student.status = @"suspended";
        
        AssertWait([student save]);
        
        STAssertEqualObjects(student.status, @"suspended", nil);
    }
    [_db clearDocumentCache];
    
    TestModelSubclass* student = [TestModelSubclass modelForDocument: [_db documentWithID: @"0001"]];
    STAssertFalse(student.isNew, nil);
    STAssertEqualObjects(student.status, @"suspended", nil);
}

- (void) test10_Properties {
    TestModel* student = [self createModelWithName: @"Pippi Langstrumpf" grade: 4];
    [student setValue:@"example" ofProperty:@"extended"];
    // propertiesToSave will include all properties
    {
        NSDictionary* expected = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"Pippi Langstrumpf", @"name", 
                                  [NSNumber numberWithInt:4], @"grade",
                                  @"example", @"extended", nil];
        STAssertEqualObjects(student.propertiesToSave, expected, nil);
    }
    // properties will not include properties that have not been explicitly defined
    {
        NSDictionary* expected = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"Pippi Langstrumpf", @"name", 
                                  [NSNumber numberWithInt:4], @"grade", nil];
        STAssertEqualObjects(student.properties, expected, nil);
    }
}

- (void) test11_setProperties {
    CouchDocument* doc = [_db untitledDocument];
    TestModelSubclass* student = [TestModelSubclass modelForDocument: doc];
    STAssertEqualObjects(student.name, nil, nil);
    STAssertEquals(student.grade, 0, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"inactive", nil);
    
    NSArray* otherNames = [NSArray arrayWithObjects:@"Alicia", @"Ali", nil];
    student.otherNames = otherNames;
    STAssertEqualObjects(student.otherNames, otherNames, nil);
    
    student.properties = [NSDictionary dictionaryWithObjectsAndKeys:@"Alice", @"name", [NSNumber numberWithInt:9], @"grade", nil];
    STAssertEqualObjects(student.name, @"Alice", nil);
    STAssertEquals(student.grade, 9, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"inactive", nil);
    STAssertEqualObjects(student.otherNames, [NSArray array], nil);

    student.properties = [NSDictionary dictionaryWithObjectsAndKeys:@"Bartholomew", @"name", nil];
    STAssertEqualObjects(student.name, @"Bartholomew", nil);
    STAssertEquals(student.grade, 0, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"inactive", nil);

    student.properties = [NSDictionary dictionaryWithObjectsAndKeys:@"suspended", @"status", nil];
    STAssertEqualObjects(student.name, nil, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"suspended", nil);
    
    student.properties =[NSDictionary dictionaryWithObjectsAndKeys:@"tricky", @"type", @"example", @"extended", nil];
    STAssertEqualObjects(student.type, @"tricky", nil); // see difference with updateProperties
    STAssertEqualObjects([student getValueOfProperty:@"extended"], @"example", nil);
}

- (void) test12_clearProperties {
    CouchDocument* doc = [_db untitledDocument];
    TestModelSubclass* student = [TestModelSubclass modelForDocument: doc];
    NSDictionary* blank = [NSDictionary dictionaryWithObjectsAndKeys:@"test-model", @"type", @"inactive", @"status", [NSArray array], @"otherNames", nil];
    STAssertEqualObjects(student.properties, blank, nil);
 
    student.properties = [NSDictionary dictionaryWithObjectsAndKeys:@"Alice", @"name", [NSNumber numberWithInt:9], @"grade", @"example", @"extended", nil];
    STAssertEqualObjects(student.name, @"Alice", nil);
    STAssertEquals(student.grade, 9, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"inactive", nil);
    STAssertEqualObjects(student.otherNames, [NSArray array], nil);
    STAssertEqualObjects([student getValueOfProperty:@"extended"], @"example", nil);
    
    [student clearProperties];
    
    STAssertEqualObjects(student.properties, blank, nil);
}

- (void) test13_updateProperties {
    CouchDocument* doc = [_db untitledDocument];
    TestModelSubclass* student = [TestModelSubclass modelForDocument: doc];
    STAssertEqualObjects(student.name, nil, nil);
    STAssertEquals(student.grade, 0, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"inactive", nil);
    
    NSArray* otherNames = [NSArray arrayWithObjects:@"Alicia", @"Ali", nil];
    student.otherNames = otherNames;
    STAssertEqualObjects(student.otherNames, otherNames, nil);
    
    [student updateProperties:[NSDictionary dictionaryWithObjectsAndKeys:@"Alice", @"name", [NSNumber numberWithInt:9], @"grade", nil]];
    STAssertEqualObjects(student.name, @"Alice", nil);
    STAssertEquals(student.grade, 9, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"inactive", nil);
    STAssertEqualObjects(student.otherNames, otherNames, nil);
    
    student.grade = 6;
    STAssertEquals(student.grade, 6, nil);
    
    [student updateProperties:[NSDictionary dictionaryWithObjectsAndKeys:@"Alicia", @"name", nil]];
    STAssertEqualObjects(student.name, @"Alicia", nil);
    STAssertEquals(student.grade, 6, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"inactive", nil);
    
    [student updateProperties:[NSDictionary dictionaryWithObjectsAndKeys:@"suspended", @"status", nil]];
    STAssertEqualObjects(student.name, @"Alicia", nil);
    STAssertEquals(student.grade, 6, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"suspended", nil);

    [student updateProperties:[NSDictionary dictionaryWithObjectsAndKeys:@"tricky", @"type", @"example", @"extended", nil]];
    STAssertEqualObjects(student.type, @"test-model", nil); // compare with updateProperties
    STAssertEqualObjects([student getValueOfProperty:@"extended"], nil, nil);
}

- (void) test14_resetProperties {
    CouchDocument* doc = [_db untitledDocument];
    TestModelSubclass* student = [TestModelSubclass modelForDocument: doc];
    NSDictionary* blank = [NSDictionary dictionaryWithObjectsAndKeys:@"test-model", @"type", @"inactive", @"status", [NSArray array], @"otherNames", nil];
    STAssertEqualObjects(student.properties, blank, nil);
    
    student.properties = [NSDictionary dictionaryWithObjectsAndKeys:@"Alice", @"name", [NSNumber numberWithInt:9], @"grade", @"example", @"extended", nil];
    
    NSArray* otherNames = [NSArray arrayWithObjects:@"Alicia", @"Ali", nil];
    student.otherNames = otherNames;
    STAssertEqualObjects(student.otherNames, otherNames, nil);
    
    STAssertEqualObjects(student.name, @"Alice", nil);
    STAssertEquals(student.grade, 9, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"inactive", nil);
    STAssertEqualObjects(student.otherNames, otherNames, nil);
    STAssertEqualObjects([student getValueOfProperty:@"extended"], @"example", nil);
    
    [student resetProperties];
    
    STAssertEqualObjects(student.name, nil, nil);
    STAssertEquals(student.grade, 0, nil);
    STAssertEqualObjects(student.type, @"test-model", nil);
    STAssertEqualObjects(student.status, @"inactive", nil);
    STAssertEqualObjects(student.otherNames, [NSArray array], nil);
    STAssertEqualObjects([student getValueOfProperty:@"extended"], @"example", nil); // not cleared out
}

- (void) test15_reload {
    NSArray* otherNames = [NSArray arrayWithObjects:@"Alicia", @"Ali", nil];
    {
        CouchDocument* doc = [_db documentWithID: @"0001"];
        TestModelSubclass* student = [TestModelSubclass modelForDocument: doc];
        student.name = @"Alice";
        student.grade = 9;
        student.status = @"active";
        student.otherNames = otherNames;
        [student setValue:@"example" ofProperty:@"extended"];
        AssertWait([student save]);
    }
    [_db clearDocumentCache];
    
    TestModelSubclass* student = [TestModelSubclass modelForDocument: [_db documentWithID: @"0001"]];
    STAssertEqualObjects(student.name, @"Alice", nil);
    STAssertEqualObjects(student.status, @"active", nil);
    STAssertEqualObjects(student.otherNames, otherNames, nil);
    STAssertEqualObjects([student getValueOfProperty:@"extended"], @"example", nil);
    
    NSDictionary *originalProperties = [student propertiesToSave];
    
    NSArray* names = [NSArray arrayWithObjects:@"Alice", @"Alicia", nil];
    
    student.name = @"Ali";
    student.status = @"suspended";
    student.otherNames = names;
    [student setValue:@"changed" ofProperty:@"extended"];
    STAssertEqualObjects(student.name, @"Ali", nil);
    STAssertEqualObjects(student.status, @"suspended", nil);
    STAssertEqualObjects(student.otherNames, names, nil);
    STAssertEqualObjects([student getValueOfProperty:@"extended"], @"changed", nil);
    
    STAssertTrue(student.needsSave, nil);
    
    [student reload]; // reload from db
    
    STAssertEqualObjects(student.name, @"Alice", nil);
    STAssertEqualObjects(student.status, @"active", nil);
    STAssertEqualObjects(student.otherNames, otherNames, nil);
    STAssertEqualObjects([student getValueOfProperty:@"extended"], @"example", nil);
    
    STAssertEqualObjects([student propertiesToSave], originalProperties, nil);
    
    STAssertFalse(student.needsSave, nil);
}

#pragma mark - UTILITIES:

- (TestModel*) createModelWithName: (NSString*)name grade: (int)grade {
    CouchDocument* doc = [_db untitledDocument];
    TestModel* student = [TestModel modelForDocument: doc];
    STAssertTrue(student.isNew, nil);
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
