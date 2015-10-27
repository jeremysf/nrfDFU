//
//  NDDFUFirmware.h
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/16/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NDDFUFirmware : NSObject {
@private
    NSURL* _url;
    NSData* _data;
}

@property (readonly, nonatomic) NSData* data;

- (id)initWithApplicationURL:(NSURL*)url;
- (BOOL)loadFileData:(NSError**)error;
- (uint16_t)crc;

@end
