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

#define PACKETS_NOTIFICATION_INTERVAL 10
#define PACKET_SIZE 20

typedef enum {
    STATE_IDLE,
    STATE_QUERYING_VERSION,
    STATE_ENTERING_BOOTLOADER,
    STATE_STARTING_UPDATE,
    STATE_ERROR
} DfuState;

@class NDDFUFirmware;
@class NDDFUDevice;

@protocol NDDFUDeviceDelegate

- (void)deviceConnected:(NDDFUDevice*)device;
- (void)deviceUpdateStatus:(NDDFUDevice*)device status:(NSString*)status;
- (void)deviceUpdateProgress:(NDDFUDevice*)device progress:(float)progress;
- (void)deviceError:(NDDFUDevice*)device error:(NSError*)error;
- (void)deviceUpdated:(NDDFUDevice*)device;

@end

@interface NDDFUDevice : NSObject<CBPeripheralDelegate> {
@private
    CBPeripheral* _peripheral;
    float _RSSI;
    CBService* _service;
    CBService* _samd21Service;
    CBCharacteristic* _controlPointCharacteristic;
    CBCharacteristic* _packetCharacteristic;
    CBCharacteristic* _versionCharacteristic;
    CBCharacteristic* _samd21ControlPointCharacteristic;
    CBCharacteristic* _samd21PacketCharacteristic;
    NSUInteger _versionMajor;
    NSUInteger _versionMinor;
    NDDFUFirmware* _firmware;
    DfuState _state;
    uint32_t _firmwareBytesSent;
    bool _updatingSamd21;
    id<NDDFUDeviceDelegate> _delegate;
}

@property (readonly, nonatomic) CBPeripheral* peripheral;
@property (nonatomic) id<NDDFUDeviceDelegate> delegate;
@property (nonatomic) float RSSI;
@property (readonly) NSUInteger versionMajor;
@property (readonly) NSUInteger versionMinor;
@property (readonly) NDDFUFirmware* firmware;

- (instancetype)initWithPeripheral:(CBPeripheral*)peripheral RSSI:(float)RSSI;
- (void)startUpdateWithApplication:(NDDFUFirmware*)firmware;
- (void)startSamd21UpdateWithApplication:(NDDFUFirmware*)firmware;
- (void)onPeripheralConnected:(CBCentralManager*)manager;
- (void)onPeripheralDisconnected:(CBCentralManager*)manager;
- (BOOL)isConnected;

@end
