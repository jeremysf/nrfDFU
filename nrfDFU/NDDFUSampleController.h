//
//  NDDFUSampleController.h
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/13/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "NDDFUDevice.h"

@interface NDDFUSampleController : NSObject<CBCentralManagerDelegate, NDDFUDeviceDelegate> {
@private
    CBCentralManager* _centralManager;
    NSArray* _devices;
    NDDFUFirmware* _firmware;
    NDDFUDevice* _deviceToUpdate;
    NSString* _deviceToUpdateUUID;
    NSString* _samd21ToUpdateUUID;
    void (^_updateCompleteHandler)(NSError* error);
}

@property (readonly) NSArray* devices;
@property (readonly) CBCentralManager* centralManager;

- (void)updateWithApplication:(NSString*)applicationFileName uuid:(NSString*)uuid completed:(void (^)(NSError* error))completed;
- (void)updateSamd21WithApplication:(NSString*)applicationFileName uuid:(NSString*)uuid completed:(void (^)(NSError* error))completed;
- (void)discover;

@end
