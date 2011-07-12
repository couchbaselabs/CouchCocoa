//
//  RESTInternal.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/25/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "RESTInternal.h"


#define kWarningPrefix @"WARNING: "


BOOL gRESTWarnRaisesException = NO;


void RESTWarn( NSString *msg, ... )
{
    va_list args;
    va_start(args,msg);

    NSLogv([kWarningPrefix stringByAppendingString: msg], args);
    
    if (gRESTWarnRaisesException)
        [NSException raise: @"RESTWarning"
                    format: msg
                 arguments: args];

    va_end(args);
    
#if TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR
    // If running in Xcode, drop into the debugger on a warning.
    // You must check the "Run > Stop On Debugger()/DebugStr()" menu item to enable this.
    Debugger();
#endif
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


