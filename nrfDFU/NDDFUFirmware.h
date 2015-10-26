//
//  NDDFUFirmware.h
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/16/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#import <Foundation/Foundation.h>

extern int const PACKET_SIZE;

@interface NDDFUFirmware : NSObject {
@private
    NSURL* _url;
    NSData* _data;
    int _numberOfPackets;
    int _bytesInLastPacket;
    int _writingPacketNumber;
}

@property (readonly, nonatomic) NSData* data;

- (id)initWithApplicationURL:(NSURL*)url;
- (BOOL)loadFileData:(NSError**)error;
- (uint16_t)crc;

@end
