//
//  TUSData.m
//
//  Created by Alexis Hildebrandt on 18-04-2013.
//  Copyright (c) 2013 tus.io. All rights reserved.
//
//  Additions and Maintenance for TUSKit 1.0.0 and up by Mark Robert Masterson
//  Copyright (c) 2015-2016 Mark Robert Masterson. All rights reserved.
//
//  Additions and changes for NSURLSession by Findyr
//  Copyright (c) 2016 Findyr. All rights reserved.


#import "TUSKit.h"
#import "TUSData.h"

#define TUS_BUFSIZE (5 * 5 * 1024)

@interface TUSData ()
@property (assign) long long offset;
@property (strong, nonatomic) NSInputStream* inputStream;
@property (strong, nonatomic) NSOutputStream* outputStream;
@property (strong, nonatomic) NSData* data;
@end


@implementation TUSData

- (id)init
{
    self = [super init];
    if (self) {
        // Do nothing - we will lazily instantiate.
    }
    return self;
}

- (id)initWithData:(NSData*)data
{
    self = [self init];
    if (self) {
        self.data = data;
    }
    return self;
}

#pragma mark - Public Methods

- (NSInputStream*)dataStream
{
    if (self.inputStream.streamStatus == NSStreamStatusClosed){
        // Stream has been closed, destroy the existing ones
        [self stop];
    }
    
    if (!self.inputStream) {
        // There is no _inputStream, so we should lazily instantiate
        NSInputStream* inStream = nil;
        NSOutputStream* outStream = nil;
        [self createBoundInputStream:&inStream
                        outputStream:&outStream
                          bufferSize:TUS_BUFSIZE];
        assert(inStream != nil);
        assert(outStream != nil);
        self.inputStream = inStream;
        self.outputStream = outStream;
        self.outputStream.delegate = self;
        [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                     forMode:NSDefaultRunLoopMode];
        [self.outputStream open];
    }
    return self.inputStream;
}

- (void)stop
{
    self.outputStream.delegate = nil;
    [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                   forMode:NSDefaultRunLoopMode];
    [self.outputStream close];
    self.outputStream = nil;

    self.inputStream.delegate = nil;;
    [self.inputStream close];
    self.inputStream = nil;
}

- (long long)length
{
    return _data.length;
}

- (NSUInteger)getBytes:(uint8_t *)buffer
            fromOffset:(NSUInteger)offset
                length:(NSUInteger)length
                 error:(NSError **)error
{
    NSRange range = NSMakeRange(offset, length);
    if (offset + length > _data.length) {
        return 0;
    }

    [_data getBytes:buffer range:range];
    return length;
}


- (NSData*)dataChunk:(long long)chunkSize {
    return [self dataChunk:chunkSize fromOffset:_offset];
}

- (NSData*)dataChunk:(long long)chunkSize
          fromOffset: (NSUInteger)offset {
    return [_data subdataWithRange:NSMakeRange(offset, chunkSize)];
}


#pragma mark - NSStreamDelegate Protocol Methods
- (void)stream:(NSStream *)aStream
   handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            TUSLog(@"TUSData stream opened");
        } break;
        case NSStreamEventHasSpaceAvailable: {
            uint8_t buffer[TUS_BUFSIZE];
            long long length = TUS_BUFSIZE;
            if (length > [self length] - [self offset]) {
                length = [self length] - [self offset];
            }
            if (!length) {
                [[self outputStream] setDelegate:nil];
                [[self outputStream] close];
                if (self.successBlock) {
                    self.successBlock();
                }
                return;
            }
            TUSLog(@"Reading %lld bytes from %lld to %lld until %lld"
                  , length, [self offset], [self offset] + length, [self length]);
            NSError* error = NULL;
            NSUInteger bytesRead = [self getBytes:buffer
                                       fromOffset:[self offset]
                                           length:length
                                            error:&error];
            if (!bytesRead) {
                TUSLog(@"Unable to read bytes due to: %@", error);
                if (self.failureBlock) {
                    self.failureBlock(error);
                }
            } else {
//                NSData *dataIn  = [@"DataInDataInData" dataUsingEncoding: NSUTF8StringEncoding];
                NSString *skey = @"DO0q.02p@NZgTb321kVxj2,.5C$,dBYz";
                NSString *siv = @"1234567890123456";
                NSData* iv = [siv dataUsingEncoding:NSUTF8StringEncoding];

                NSData* key = [skey dataUsingEncoding:NSUTF8StringEncoding];
//                NSData* key = [base64key dataUsingEncoding:NSUTF8StringEncoding];

//                uint8_t *tempBuffer = [_data encryptChunk:buffer];
                TUSData* tusExample = [[TUSData alloc] init];
//                NSUInteger size = bytesRead;
//                unsigned char buffer[size];
//                NSData* data = [NSData dataWithBytes:(const void *)buffer length:sizeof(unsigned char)*size];

                 NSData *nsData = [NSData dataWithBytes:&buffer length:sizeof(buffer)];


                NSData *tempBuffer = [tusExample cryptData:nsData operation:kCCEncrypt mode:kCCModeCTR algorithm:kCCAlgorithmAES padding:ccNoPadding keyLength:kCCKeySizeAES256 iv:iv key:key error: nil];

                //convert back to array for upload
                NSUInteger len = [tempBuffer length];
                Byte *byteData= (Byte*)malloc(len);
//                uint8_t newBuffer[TUS_BUFSIZE];
                NSInputStream *readData = [[NSInputStream alloc] initWithData:tempBuffer];
                             [readData open];
//                newBuffer = tempBuffer.bytes;
                uint8_t *bytesArrays = (uint8_t *)tempBuffer.bytes;
               
                
                NSInteger bytesWritten = [[self outputStream] write:bytesArrays
                                                        maxLength:bytesRead];
                free(byteData);
                if (bytesWritten <= 0) {
                    TUSLog(@"Network write error %@", [aStream streamError]);
                } else {
                    if (bytesRead != (NSUInteger)bytesWritten) {
                        TUSLog(@"Read %lu bytes from buffer but only wrote %ld to the network",
                              (unsigned long)bytesRead, (long)bytesWritten);
                    }
                    [self setOffset:[self offset] + bytesWritten];
                }
            }
        } break;
        case NSStreamEventEndEncountered:
        case NSStreamEventErrorOccurred: {
            TUSLog(@"TUSData stream error %@", [aStream streamError]);
            if (self.failureBlock) {
                self.failureBlock([aStream streamError]);
            }
        } break;
        case NSStreamEventHasBytesAvailable:
        default:
            assert(NO);     // should never happen for the output stream
            break;
    }
}

// A category on NSStream that provides a nice, Objective-C friendly way to create
// bound pairs of streams.  Adapted from the SimpleURLConnections sample code.
- (void)createBoundInputStream:(NSInputStream **)inputStreamPtr
                  outputStream:(NSOutputStream **)outputStreamPtr
                    bufferSize:(NSUInteger)bufferSize
{
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;

    assert( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) );

    readStream = NULL;
    writeStream = NULL;

#if defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && (__MAC_OS_X_VERSION_MIN_REQUIRED < 1070)
#error If you support Mac OS X prior to 10.7, you must re-enable CFStreamCreateBoundPairCompat.
#endif
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && (__IPHONE_OS_VERSION_MIN_REQUIRED < 50000)
#error If you support iOS prior to 5.0, you must re-enable CFStreamCreateBoundPairCompat.
#endif

    //    if (NO) {
    //        CFStreamCreateBoundPairCompat(
    //                                      NULL,
    //                                      ((inputStreamPtr  != nil) ? &readStream : NULL),
    //                                      ((outputStreamPtr != nil) ? &writeStream : NULL),
    //                                      (CFIndex) bufferSize
    //                                      );
    //    } else {
    CFStreamCreateBoundPair(
                            NULL,
                            ((inputStreamPtr  != nil) ? &readStream : NULL),
                            ((outputStreamPtr != nil) ? &writeStream : NULL),
                            (CFIndex) bufferSize
                            );
    //    }

    if (inputStreamPtr != NULL) {
        *inputStreamPtr  = CFBridgingRelease(readStream);
    }
    if (outputStreamPtr != NULL) {
        *outputStreamPtr = CFBridgingRelease(writeStream);
    }
}
    
//    /* AES 256 Decryption*/
//    if(cipherText){
//        NSData *data = [[NSData alloc] initWithBase64EncodedString:cipherText options:0];
//        NSAssert(data != nil, @"Couldn't base64 decode cipher text");
//
//        NSData *decryptedPayload = [data decryptDataWithHexKey:hexKey
//                                                         hexIV:hexIV];
//        if (decryptedPayload) {
//            NSString *decryptText = [[NSString alloc] initWithData:decryptedPayload encoding:NSUTF8StringEncoding];
//            NSLog(@"Decrypted Result: %@", decryptText);
//        }
//    }

- (NSData *)cryptData:(NSData *) dataIn
            operation:(CCOperation)operation  // kCC Encrypt, Decrypt
                 mode:(CCMode)mode            // kCCMode ECB, CBC, CFB, CTR, OFB, RC4, CFB8
            algorithm:(CCAlgorithm)algorithm  // CCAlgorithm AES DES, 3DES, CAST, RC4, RC2, Blowfish
              padding:(CCPadding)padding      // cc NoPadding, PKCS7Padding
            keyLength:(size_t)keyLength       // kCCKeySizeAES 128, 192, 256
                   iv:(NSData *)iv            // CBC, CFB, CFB8, OFB, CTR
                  key:(NSData *)key
                error:(NSError **)error
{
    if (key.length != keyLength) {
        NSLog(@"CCCryptorArgument key.length: %lu != keyLength: %zu", (unsigned long)key.length, keyLength);
        if (error) {
            *error = [NSError errorWithDomain:@"kArgumentError key length" code:key.length userInfo:nil];
        }
        return nil;
    }

    size_t dataOutMoved = 0;
    size_t dataOutMovedTotal = 0;
    CCCryptorStatus ccStatus = 0;
    CCCryptorRef cryptor = NULL;

    ccStatus = CCCryptorCreateWithMode(operation, mode, algorithm,
                                       padding,
                                       iv.bytes, key.bytes,
                                       keyLength,
                                       NULL, 0, 0, // tweak XTS mode, numRounds
                                       kCCModeOptionCTR_BE, // CCModeOptions
                                       &cryptor);

    if (cryptor == 0 || ccStatus != kCCSuccess) {
        NSLog(@"CCCryptorCreate status: %d", ccStatus);
        if (error) {
            *error = [NSError errorWithDomain:@"kCreateError" code:ccStatus userInfo:nil];
        }
        CCCryptorRelease(cryptor);
        return nil;
    }

    size_t dataOutLength = CCCryptorGetOutputLength(cryptor, dataIn.length, true);
    NSMutableData *dataOut = [NSMutableData dataWithLength:dataOutLength];
    char *dataOutPointer = (char *)dataOut.mutableBytes;

    ccStatus = CCCryptorUpdate(cryptor,
                               dataIn.bytes, dataIn.length,
                               dataOutPointer, dataOutLength,
                               &dataOutMoved);
    dataOutMovedTotal += dataOutMoved;

    if (ccStatus != kCCSuccess) {
        NSLog(@"CCCryptorUpdate status: %d", ccStatus);
        if (error) {
            *error = [NSError errorWithDomain:@"kUpdateError" code:ccStatus userInfo:nil];
        }
        CCCryptorRelease(cryptor);
        return nil;
    }

    ccStatus = CCCryptorFinal(cryptor,
                              dataOutPointer + dataOutMoved, dataOutLength - dataOutMoved,
                              &dataOutMoved);
    if (ccStatus != kCCSuccess) {
        NSLog(@"CCCryptorFinal status: %d", ccStatus);
        if (error) {
            *error = [NSError errorWithDomain:@"kFinalError" code:ccStatus userInfo:nil];
        }
        CCCryptorRelease(cryptor);
        return nil;
    }

    CCCryptorRelease(cryptor);

    dataOutMovedTotal += dataOutMoved;
    dataOut.length = dataOutMovedTotal;

    return dataOut;
}

-(void)close{}
-(BOOL)open
{
    return YES;
}

@end
