//
//  TUSData.h
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.
//
//  Additions and changes for NSURLSession by Findyr
//  Copyright (c) 2016 Findyr. All rights reserved.


#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>

@interface TUSData : NSObject <NSStreamDelegate>

@property (readwrite,copy) void (^failureBlock)(NSError* error);
@property (readwrite,copy) void (^successBlock)(void);
@property (readonly) NSInputStream* dataStream;

- (id)initWithData:(NSData*)data;

- (long long)length;
- (void)stop;
- (void)setOffset:(long long)offset;
- (BOOL)open; // Re-open a closed TUSData object if it can be. Return YES if the TUSData object is open after the call.
- (void)close; // Close this TUSData object if it can be

- (NSData*)dataChunk:(long long)chunkSize;

- (NSData*)dataChunk:(long long)chunkSize
          fromOffset: (NSUInteger)offset;

- (NSData *)cryptData:(NSData *) dataIn
            operation:(CCOperation)operation  // kCC Encrypt, Decrypt
                 mode:(CCMode)mode            // kCCMode ECB, CBC, CFB, CTR, OFB, RC4, CFB8
            algorithm:(CCAlgorithm)algorithm  // CCAlgorithm AES DES, 3DES, CAST, RC4, RC2, Blowfish
              padding:(CCPadding)padding      // cc NoPadding, PKCS7Padding
            keyLength:(size_t)keyLength       // kCCKeySizeAES 128, 192, 256
                   iv:(NSData *)iv            // CBC, CFB, CFB8, OFB, CTR
                  key:(NSData *)key
                error:(NSError **)error;
@end
