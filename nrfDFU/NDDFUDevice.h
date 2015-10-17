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

typedef enum {
    START_INIT_PACKET = 0x00,
    END_INIT_PACKET = 0x01
} initPacketParam;

typedef enum {
    START_DFU_REQUEST = 0x01,
    INITIALIZE_DFU_PARAMETERS_REQUEST = 0x02,
    RECEIVE_FIRMWARE_IMAGE_REQUEST = 0x03,
    VALIDATE_FIRMWARE_REQUEST = 0x04,
    ACTIVATE_AND_RESET_REQUEST = 0x05,
    RESET_SYSTEM = 0x06,
    PACKET_RECEIPT_NOTIFICATION_REQUEST = 0x08,
    RESPONSE_CODE = 0x10,
    PACKET_RECEIPT_NOTIFICATION_RESPONSE = 0x11
} DfuOperations;

typedef enum {
    OPERATION_SUCCESSFUL_RESPONSE = 0x01,
    OPERATION_INVALID_RESPONSE = 0x02,
    OPERATION_NOT_SUPPORTED_RESPONSE = 0x03,
    DATA_SIZE_EXCEEDS_LIMIT_RESPONSE = 0x04,
    CRC_ERROR_RESPONSE = 0x05,
    OPERATION_FAILED_RESPONSE = 0x06
} DfuOperationStatus;

typedef enum {
    SOFTDEVICE = 0x01,
    BOOTLOADER = 0x02,
    SOFTDEVICE_AND_BOOTLOADER = 0x03,
    APPLICATION = 0x04
} DfuFirmwareTypes;

@class NDDFUController;

@interface NDDFUDevice : NSObject<CBPeripheralDelegate> {
@private
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
