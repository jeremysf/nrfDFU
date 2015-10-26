//
//  NDDFUFirmware.m
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/16/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#import "NDDFUFirmware.h"

int const PACKET_SIZE = 20;

@implementation NDDFUFirmware

@synthesize data = _data;

- (id)initWithApplicationURL:(NSURL*)fileURL {
    self = [super init];
    if( self != nil ) {
        _url = fileURL;
    }
    return self;
}


- (BOOL)loadFileData:(NSError**)error
{
    if( ![[[_url pathExtension] lowercaseString] isEqualToString:@"bin"] ) {
        *error = [NSError errorWithDomain:@"DFU"
                                     code:0
                                 userInfo:@{NSLocalizedDescriptionKey: @"Only .bin format files supported."}];
        return NO;
    }
    _data = [NSData dataWithContentsOfURL:_url];
    if( _data == nil ) {
        *error = [NSError errorWithDomain:@"DFU"
                                     code:0
                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unable to read contents of '%@'.", [_url absoluteString]]}];
        return NO;
    }
    _numberOfPackets = ceil((double)_data.length / (double)PACKET_SIZE);
    _bytesInLastPacket = (_data.length % PACKET_SIZE);
    if( _bytesInLastPacket == 0 ) {
        _bytesInLastPacket = PACKET_SIZE;
    }
    _writingPacketNumber = 0;
    return YES;
}

// this routine is from the nRF51_SDK_9/components/libraries/crc16/crc16.c
/* Copyright (c) 2013 Nordic Semiconductor. All Rights Reserved.
 *
 * The information contained herein is property of Nordic Semiconductor ASA.
 * Terms and conditions of usage are described in detail in NORDIC
 * SEMICONDUCTOR STANDARD SOFTWARE LICENSE AGREEMENT.
 *
 * Licensees are granted free, non-transferable use of the information. NO
 * WARRANTY of ANY KIND is provided. This heading must NOT be removed from
 * the file.
 *
 */
uint16_t crc16_compute(const uint8_t * p_data, uint32_t size, const uint16_t * p_crc)
{
    uint32_t i;
    uint16_t crc = (p_crc == NULL) ? 0xffff : *p_crc;
    
    for (i = 0; i < size; i++)
    {
        crc  = (unsigned char)(crc >> 8) | (crc << 8);
        crc ^= p_data[i];
        crc ^= (unsigned char)(crc & 0xff) >> 4;
        crc ^= (crc << 8) << 4;
        crc ^= ((crc & 0xff) << 4) << 1;
    }
    
    return crc;
}

- (uint16_t)crc {
    return crc16_compute(_data.bytes, (uint32_t)_data.length, NULL);
}

@end
