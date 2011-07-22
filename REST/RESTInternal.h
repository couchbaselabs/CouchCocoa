//
//  RESTInternal.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/25/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "REST.h"
#import "RESTCache.h"


void RESTWarn(NSString* format, ...) __attribute__((format(__NSString__, 1, 2)));;

#define Warn RESTWarn

extern BOOL gRESTWarnRaisesException;


#define $castIf(CLASSNAME,OBJ)      ((CLASSNAME*)(RESTCastIf([CLASSNAME class],(OBJ))))
#define $castIfArrayOf(ITEMCLASSNAME,OBJ) RESTCastArrayOf([ITEMCLASSNAME class],(OBJ)))
id RESTCastIf(Class,id);
id RESTCastIfArrayOf(Class,id);



@interface RESTResource ()
@property (readwrite, retain) RESTCache* owningCache;
@end


@interface RESTCache ()
- (void) resourceBeingDealloced:(RESTResource*)resource;
@end


@interface NSArray (RESTExtensions)
- (NSArray*) rest_map: (id (^)(id obj))block;
@end