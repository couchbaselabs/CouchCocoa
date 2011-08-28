//
//  AddressCard.h
//  CouchCocoa
//
//  Created by Jens Alfke on 8/26/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchModel.h"

@interface AddressCard : CouchModel

@property (copy) NSString* first;
@property (copy) NSString* last;
@property (copy) NSString* email;

@end
