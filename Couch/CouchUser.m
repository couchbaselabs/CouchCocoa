//
//  CouchUser.m
//  CouchCocoa
//
//  Created by Fabien Franzen on 20-06-12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "CouchUser.h"
#import "CouchInternal.h"

static NSString*  const kUserIDPrefix = @"org.couchdb.user:";
static NSUInteger const kUserIDPrefixLength = 17;

@implementation CouchUser

@dynamic type, name, roles;

+ (NSString*) userIDWithName:(NSString*)name {
    NSString* formatted = [name lowercaseString];
    return [NSString stringWithFormat:@"%@%@", kUserIDPrefix, formatted];
}

- (void) setPassword:(NSString*)password {
    [self setValue:password ofProperty:@"password"];
}

- (BOOL) setDefaultValues {
    NSString* name = [[[self document] documentID] substringFromIndex:kUserIDPrefixLength];
    [self setDefault:@"user" ofProperty:@"type"];
    [self setDefault:name ofProperty:@"name"];
    [self setDefault:[NSArray array] ofProperty:@"roles"];
    return YES;
}

@end
