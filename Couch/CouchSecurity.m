//
//  CouchSecurity.m
//  CouchCocoa
//
//  Created by Fabien Franzen on 20-06-12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "CouchSecurity.h"
#import "CouchUser.h"
#import "CouchInternal.h"

@interface CouchSecurity ()
- (BOOL)load;
@end

@implementation CouchSecurity

- (id)initWithDatabase: (CouchDatabase*)database {
    self = [super init];
    if(self) {
        _resource = [[CouchResource alloc] initWithParent:database relativePath: @"_security"];
        [_resource retain];
    }
    return self;
}    

@dynamic adminNames, adminRoles, readerNames, readerRoles, dropBox;

- (void)dealloc {
    [_resource release];
    [_properties release];
    [super dealloc];
}

- (NSString*)keyPathForProperty:(NSString*)key {
    static NSDictionary* mapping = nil;
    if (mapping == nil) {
        mapping = [NSDictionary dictionaryWithObjectsAndKeys:
                    @"admins.names",  kSecurityAdminNamesKey, 
                    @"admins.roles",  kSecurityAdminRolesKey,
                    @"readers.names", kSecurityReaderNamesKey,
                    @"readers.roles", kSecurityReaderRolesKey,
                    nil];
    }
    return [mapping objectForKey:key];
}

- (id) getValueOfProperty: (NSString*)property {
    NSString* keyPath = [self keyPathForProperty:property];
    if (!keyPath) keyPath = property;
    return [self.properties valueForKeyPath:keyPath];
}

- (BOOL) setValue: (id)value ofProperty: (NSString*)property {
    NSString* keyPath = [self keyPathForProperty:property];
    if (!keyPath) keyPath = property;
    [self.properties setValue:value forKeyPath:keyPath];
    return YES;
}

- (void)addObject:(id)obj forProperty:(NSString *)property {
    id prop = [self getValueOfProperty:property];
    if ([prop respondsToSelector:@selector(addObject:)]) {
        if (![prop containsObject:obj]) [prop addObject:obj];
    }
}

- (void)removeObject:(id)obj forProperty:(NSString *)property {
    id prop = [self getValueOfProperty:property];
    if ([prop respondsToSelector:@selector(removeObject:)]) {
        [prop removeObject:obj];
    }
}

- (NSDictionary *)properties {
    if (!_properties) {        
        _properties = [[NSMutableDictionary dictionary] retain];
        [_properties setValue:[NSMutableDictionary dictionary] forKey:@"admins"];
        [_properties setValue:[NSMutableDictionary dictionary] forKey:@"readers"];
        [_properties setValue:[NSMutableArray array] forKeyPath:@"admins.names"];
        [_properties setValue:[NSMutableArray array] forKeyPath:@"admins.roles"];
        [_properties setValue:[NSMutableArray array] forKeyPath:@"readers.names"];
        [_properties setValue:[NSMutableArray array] forKeyPath:@"readers.roles"];
        [self load];
    }
    return _properties;
}

- (RESTOperation*)update {
    return [_resource PUTJSON: self.properties parameters: nil];
}

- (BOOL)load {
    RESTOperation* op = [_resource GET];
    if ([op wait]) {
        NSDictionary* response = $castIf(NSDictionary, op.responseBody.fromJSON);
        if (response && response.count > 0) {
            NSSet *writableNames = [self.class writablePropertyNames];
            [writableNames enumerateObjectsUsingBlock:^(id key, BOOL *stop) {
                NSString* keyPath = [self keyPathForProperty:key];
                if (!keyPath) keyPath = key;
                id value = [response valueForKeyPath:keyPath];
                if ([[self.class classOfProperty:key] isSubclassOfClass:[NSArray class]]) {
                    if (value) {
                        value = [[value mutableCopy] autorelease];
                    } else {
                        value = [NSMutableArray array];
                    }
                }
                [self.properties setValue:value forKeyPath:keyPath];
            }];
        }
        return YES;
    } 
    return NO;
}

@end
