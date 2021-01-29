//
//  TUSResumableUpload.h
//
//  Originally Created by Felix Geisendoerfer on 07.04.13.
//  Copyright (c) 2013 Felix Geisendoerfer. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.
//
//  Additions and changes for NSURLSession by Findyr
//  Copyright (c) 2016 Findyr

@import Foundation;
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>

typedef NS_ENUM(NSInteger, TUSResumableUploadState) {
    TUSResumableUploadStateCreatingFile,
    TUSResumableUploadStateCheckingFile,
    TUSResumableUploadStateUploadingFile,
    TUSResumableUploadStateComplete
};


typedef void (^TUSUploadResultBlock)(NSURL* _Nonnull fileURL);
typedef void (^TUSUploadFailureBlock)(NSError* _Nonnull error);
typedef void (^TUSUploadProgressBlock)(int64_t bytesWritten, int64_t bytesTotal);

@interface TUSResumableUpload : NSObject<NSCoding>
@property (readwrite, copy) _Nullable TUSUploadResultBlock resultBlock;
@property (readwrite, copy) _Nullable TUSUploadFailureBlock failureBlock;
@property (readwrite, copy) _Nullable TUSUploadProgressBlock progressBlock;

/**
 The unique ID for the upload object
 */
@property (readonly) NSString * _Nonnull uploadId;

/**
 The upload is complete if the file has been completely uploaded to the TUS server
*/
 @property (readonly) BOOL complete;
 

/**
 The upload is idle if no HTTP tasks are currently outstanding for it
 */
@property (readonly) BOOL idle;

/**
 The current state of the upload
 */
@property (readonly) TUSResumableUploadState state;

/**
 Permanently cancel this upload.  If cancelled, it cannot be resumed
 */
-(BOOL)cancel;

/**
 Temporarily stop this upload.
 */
-(BOOL)stop;

/**
 Resume the upload if it was cancelled or not yet started
 */
- (BOOL) resume;

/**
 Lazily instantiate the chunkSize for the upload
 */
- (void)setChunkSize:(long long)chunkSize;

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

