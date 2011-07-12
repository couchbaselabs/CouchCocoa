//
//  CouchResource.m
//  CouchCocoa
//
//  Created by Jens Alfke on 5/29/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchResource.h"
#import "RESTInternal.h"


NSString* const kCouchDBErrorDomain = @"CouchDB";


@implementation CouchResource


- (CouchDatabase*) database {
    return [(CouchResource*)self.parent database];
    // No, this is not an infinite regress. CouchDatabase overrides this to return self.
}


- (NSError*) operation: (RESTOperation*)op willCompleteWithError: (NSError*)error {
    error = [super operation: op willCompleteWithError: error];

    int httpStatus = op.httpStatus;
    if (httpStatus == 0)
        return error;   // Some kind non-HTTP error


    if (httpStatus >= 400) {
        NSDictionary* json = $castIf(NSDictionary, op.responseBody.fromJSON);
        if (json) {
            // Interpret extra error info in JSON body of op:
            NSString* errorName = [[json objectForKey: @"error"] description];
            if (errorName) {
                NSString* reason = [[json objectForKey: @"reason"] description];
                if (reason)
                    reason = [NSString stringWithFormat: @"%@: %@", errorName, reason];
                NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
                                      error, NSUnderlyingErrorKey,
                                      errorName, NSLocalizedFailureReasonErrorKey,
                                      reason, NSLocalizedDescriptionKey,
                                      nil];
                error = [NSError errorWithDomain: kCouchDBErrorDomain code: error.code
                                        userInfo: info];
            }
        }
    }
    return error;
}


@end
