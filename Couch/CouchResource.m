//
//  CouchResource.m
//  CouchCocoa
//
//  Created by Jens Alfke on 5/29/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CouchResource.h"
#import "RESTInternal.h"


NSString* const kCouchDBErrorDomain = @"CouchDB";


@implementation CouchResource


- (CouchDatabase*) database {
    return [(CouchResource*)self.parent database];
    // No, this is not an infinite regress. CouchDatabase overrides this to return self.
}


- (CouchResource*) childWithPath: (NSString*)relativePath {
    return [[CouchResource alloc] initWithParent: self relativePath: relativePath];
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
