//
//  NDDFUDevice.h
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/13/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

extern NSString *const kDeviceDFUServiceUUID;
extern NSString *const kDeviceControlPointCharacteristicUUID;
extern NSString *const kDevicePacketCharacteristicUUID;
extern NSString *const kDeviceVersionCharacteristicUUID;

extern NSString *const kDeviceConnectionNotification;

@class NDDFUController;

@interface NDDFUDevice : NSObject<CBPeripheralDelegate> {
    NDDFUController* _controller;
    CBPeripheral* _peripheral;
    float _RSSI;
    CBService* _service;
    CBCharacteristic* _controlPointCharacteristic;
    CBCharacteristic* _packetCharacteristic;
    CBCharacteristic* _versionCharacteristic;
}

@property (readonly, nonatomic) CBPeripheral* peripheral;
@property (nonatomic) float RSSI;

- (instancetype)initWithPeripheral:(CBPeripheral*)peripheral RSSI:(float)RSSI controller:(NDDFUController*)controller;
- (void)updateWithApplication:(NSString*)applicationFileName completed:(void (^)(NSError* error))completed;
- (void)refresh;
- (BOOL)isConnected;

@end
