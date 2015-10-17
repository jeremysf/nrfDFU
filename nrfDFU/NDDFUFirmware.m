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

@end
