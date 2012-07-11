//
//  Test_Security.m
//  CouchCocoa
//
//  Created by Fabien Franzen on 21-06-12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "CouchInternal.h"
#import "CouchTestCase.h"

@interface Test_Security : CouchTestCase
@end

@implementation Test_Security

- (void)tearDown {
    CouchUser* user = [_server userWithName:@"Alice"];
    if (!user.isNew) {
        RESTOperation* op = [user deleteDocument];
        if (![op wait]) NSLog(@"Failed to delete user: %@", user);
    }
    [super tearDown];
}


- (void) test0_userWithName {
    NSArray* roles = [NSArray arrayWithObjects:@"viewer", nil];
    {
        CouchUser* user = [_server userWithName:@"Alice"];
        STAssertEqualObjects(user.document.documentID, @"org.couchdb.user:alice", nil);
        STAssertEqualObjects(user.name, @"alice", nil); // note how it auto-formats the name
        STAssertEqualObjects(user.roles, [NSArray array], nil);
        
        STAssertFalse(user.exists, nil);
        STAssertTrue(user.needsSave, nil);
        
        AssertWait([user save]);
        
        STAssertTrue(user.exists, nil);
        STAssertFalse(user.needsSave, nil);
        
        // without a password, the following properties are empty
        STAssertNil([user getValueOfProperty:@"derived_key"], nil);
        STAssertNil([user getValueOfProperty:@"password_scheme"], nil);
        STAssertNil([user getValueOfProperty:@"salt"], nil);
        STAssertNil([user getValueOfProperty:@"iterations"], nil);
        
        [user setPassword:@"secret"];
        STAssertNotNil([user getValueOfProperty:@"password"], nil);
        
        [user setRoles:roles];
        STAssertEqualObjects(user.roles, roles, nil);
        
        [user setValue:@"Alice" ofProperty:@"firstname"];
        [user setValue:@"Wonderland" ofProperty:@"lastname"];
        
        AssertWait([user save]);
    }
    [_db clearDocumentCache];
    
    CouchUser* user = [_server userWithName:@"alice"];
    
    STAssertNil([user getValueOfProperty:@"password"], nil);
    STAssertEqualObjects(user.roles, roles, nil);
    
    STAssertEqualObjects([user getValueOfProperty:@"firstname"], @"Alice", nil);
    STAssertEqualObjects([user getValueOfProperty:@"lastname"], @"Wonderland", nil);
    
    // with a password, the following properties will have some values
    STAssertNotNil([user getValueOfProperty:@"derived_key"], nil);
    STAssertNotNil([user getValueOfProperty:@"password_scheme"], nil);
    STAssertNotNil([user getValueOfProperty:@"salt"], nil);
    STAssertNotNil([user getValueOfProperty:@"iterations"], nil);
}

- (void) test1_security {
    NSArray* names = [NSArray arrayWithObjects:@"alice", @"bob", nil];
    NSArray* roles = [NSArray arrayWithObjects:@"boss", nil];
    {
        CouchSecurity* security = [_db security];
        
        security.adminRoles = roles;
        STAssertEqualObjects(security.adminRoles, roles, nil);
        
        security.readerNames = names;
        STAssertEqualObjects(security.readerNames, names, nil);
        
        STAssertEqualObjects(security.adminNames, [NSArray array], nil);
        STAssertEqualObjects(security.readerRoles, [NSArray array], nil);
        
        AssertWait([security update]);
    }
    
    {
        CouchSecurity* security = [_db security];
        STAssertEqualObjects(security.adminRoles, roles, nil);
        STAssertEqualObjects(security.readerNames, names, nil);
        
        STAssertEqualObjects(security.adminNames, [NSArray array], nil);
        STAssertEqualObjects(security.readerRoles, [NSArray array], nil);

        [security addObject:@"bob" forProperty:kSecurityAdminNamesKey];
        STAssertTrue([security.adminNames containsObject:@"bob"],nil);
        
        [security addObject:@"viewer" forProperty:kSecurityReaderRolesKey];
        STAssertTrue([security.readerRoles containsObject:@"viewer"],nil);
        
        AssertWait([security update]);
    }
    
    {
        CouchSecurity* security = [_db security];
        STAssertEqualObjects(security.readerNames, names, nil);
        
        STAssertTrue([security.adminNames containsObject:@"bob"],nil);
        STAssertTrue([security.readerRoles containsObject:@"viewer"],nil);
        
        [security removeObject:@"alice" forProperty:kSecurityReaderNamesKey];
        STAssertEqualObjects(security.readerNames, [NSArray arrayWithObject:@"bob"], nil);
        
        [security removeObject:@"viewer" forProperty:kSecurityReaderRolesKey];
        STAssertEqualObjects(security.readerRoles, [NSArray array], nil);
    }
}

@end
