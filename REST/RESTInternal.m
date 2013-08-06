//
//  RESTInternal.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/25/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "RESTInternal.h"


#define kWarningPrefix @"WARNING: "


BOOL gRESTWarnRaisesException = NO;


void RESTWarn( NSString *msg, ... )
{
    va_list args;
    va_start(args,msg);
    NSLogv([kWarningPrefix stringByAppendingString: msg], args);
    va_end(args);
    
    if (gRESTWarnRaisesException) {
        va_start(args,msg);
        [NSException raise: @"RESTWarning"
                    format: msg
                 arguments: args];
    }
}


id RESTCastIf( Class requiredClass, id object )
{
    if( object && ! [object isKindOfClass: requiredClass] ) {
        Warn(@"$castIf: Expected %@, got %@ %@", requiredClass, [object class], object);
        object = nil;
    }
    return object;
}

NSArray* RESTCastIfArrayOf(Class itemClass, id object)
{
    NSArray* array = $castIf(NSArray, object);
    for( id item in array ) {
        if (![item isKindOfClass: itemClass]) {
            Warn(@"$castIfArrayOf: Expected %@, got %@ %@", itemClass, [item class], item);
            return nil;
        }
    }
    return array;
}

NSString *EscapeRelativePath(NSString *path) {
    /*
     Escapes reserved URI characters.
     RFC 3986 section 2.2 http://www.ietf.org/rfc/rfc3986.txt
     */
    CFStringRef escapedPath = CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                      (CFStringRef)path,
                                                                      NULL,
                                                                      (CFStringRef)@":/?#[]@!$&'()*+,;=",
                                                                      kCFStringEncodingUTF8);
    return [(NSString *)escapedPath autorelease];
}

@implementation NSArray (RESTExtensions)

- (NSArray*) rest_map: (id (^)(id obj))block {
    NSMutableArray* mapped = [[NSMutableArray alloc] initWithCapacity: self.count];
    for (id obj in self) {
        obj = block(obj);
        if (obj)
            [mapped addObject: obj];
    }
    NSArray* result = [[mapped copy] autorelease];
    [mapped release];
    return result;
}

@end
