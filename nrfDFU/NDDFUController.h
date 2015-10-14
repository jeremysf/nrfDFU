//
//  NDDFUController.h
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/13/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@class NDDFUDevice;

extern NSString *const kDeviceDiscoveryNotification;

@interface NDDFUController : NSObject<CBCentralManagerDelegate> {
@private
    CBCentralManager* _centralManager;
    NSArray* _devices;
}

@property (readonly) NSArray* devices;

- (void)updateWithApplication:(NSString*)applicationFileName uuid:(NSString*)uuid completed:(void (^)(NSError* error))completed;
- (void)discover;

- (void)connect:(NDDFUDevice*)device connected:(void (^)(NSError* error))connected;

@end
