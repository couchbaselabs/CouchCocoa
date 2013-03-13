//
//  RESTBase64.m
//  CouchCocoa
//
//  Created by Jens Alfke on 9/14/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "RESTBase64.h"

// Based on public-domain source code by cyrus.najmabadi@gmail.com 
// taken from http://www.cocoadev.com/index.pl?BaseSixtyFour


@implementation RESTBase64


static const uint8_t kEncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static int8_t kDecodingTable[256];

+ (void) initialize {
    if (self == [RESTBase64 class]) {
        memset(kDecodingTable, 0xFF, sizeof(kDecodingTable));
        for (NSInteger i = 0; i < sizeof(kEncodingTable); i++) {
            kDecodingTable[kEncodingTable[i]] = i;
        }
    }
}


+ (NSString*) encode: (const void*)input length: (size_t)length {
    if (input == NULL)
        return nil;
    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t* output = (uint8_t*)data.mutableBytes;
    
    for (NSInteger i = 0; i < length; i += 3) {
        NSInteger value = 0;
        for (NSInteger j = i; j < (i + 3); j++) {
            value <<= 8;
            
            if (j < length) {
                value |= ((const uint8_t*)input)[j];
            }
        }
        
        NSInteger index = (i / 3) * 4;
        output[index + 0] =                    kEncodingTable[(value >> 18) & 0x3F];
        output[index + 1] =                    kEncodingTable[(value >> 12) & 0x3F];
        output[index + 2] = (i + 1) < length ? kEncodingTable[(value >> 6)  & 0x3F] : '=';
        output[index + 3] = (i + 2) < length ? kEncodingTable[(value >> 0)  & 0x3F] : '=';
    }
    
    return [[NSString alloc] initWithData:data
                                  encoding:NSASCIIStringEncoding];
}


+ (NSString*) encode: (NSData*)rawBytes {
    return [self encode: rawBytes.bytes length: rawBytes.length];
}


+ (NSData*) decode: (const char*)string length: (size_t)inputLength {
    if ((string == NULL) || (inputLength % 4 != 0)) {
        return nil;
    }
    
    while (inputLength > 0 && string[inputLength - 1] == '=') {
        inputLength--;
    }
    
    size_t outputLength = inputLength * 3 / 4;
    NSMutableData* data = [NSMutableData dataWithLength:outputLength];
    uint8_t* output = data.mutableBytes;
    
    NSInteger inputPoint = 0;
    NSInteger outputPoint = 0;
    while (inputPoint < inputLength) {
        uint8_t i0 = string[inputPoint++];
        uint8_t i1 = string[inputPoint++];
        uint8_t i2 = inputPoint < inputLength ? string[inputPoint++] : 'A'; /* 'A' will decode to \0 */
        uint8_t i3 = inputPoint < inputLength ? string[inputPoint++] : 'A';
        
        if (kDecodingTable[i0] < 0 || kDecodingTable[i1] < 0 
                || kDecodingTable[i2] < 0 || kDecodingTable[i3] < 0)
            return nil;
                
        output[outputPoint++] = (kDecodingTable[i0] << 2) | (kDecodingTable[i1] >> 4);
        if (outputPoint < outputLength) {
            output[outputPoint++] = ((kDecodingTable[i1] & 0xf) << 4) | (kDecodingTable[i2] >> 2);
        }
        if (outputPoint < outputLength) {
            output[outputPoint++] = ((kDecodingTable[i2] & 0x3) << 6) | kDecodingTable[i3];
        }
    }
    
    return data;
}


+ (NSData*) decode:(NSString*) string {
    NSData* ascii = [string dataUsingEncoding: NSASCIIStringEncoding];
    return [self decode: ascii.bytes length: ascii.length];
}


@end
