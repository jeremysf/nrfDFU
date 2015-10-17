//
//  NDDFUDevice.m
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/13/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#import "NDDFUDevice.h"
#import "NDDFUController.h"
#import "NDDFUFirmware.h"

NSString *const kDeviceDFUServiceUUID = @"00001530-1212-EFDE-1523-785FEABCD123";
NSString *const kDeviceControlPointCharacteristicUUID = @"00001531-1212-EFDE-1523-785FEABCD123";
NSString *const kDevicePacketCharacteristicUUID = @"00001532-1212-EFDE-1523-785FEABCD123";
NSString *const kDeviceVersionCharacteristicUUID = @"00001534-1212-EFDE-1523-785FEABCD123";

NSString *const kDeviceConnectionNotification = @"kDeviceConnectionNotification";

@interface NDDFUDevice () {
    void (^_versionCallback)(uint8_t major, uint8_t minor, NSError *error);
}

@end

@implementation NDDFUDevice

@synthesize peripheral = _peripheral;
@synthesize RSSI = _RSSI;


- (instancetype)initWithPeripheral:(CBPeripheral*)peripheral RSSI:(float)RSSI controller:(NDDFUController *)controller {
    self = [super init];
    if( self ) {
        _controller = controller;
        _peripheral = peripheral;
        _peripheral.delegate = self;
        _controlPointCharacteristic = nil;
        _packetCharacteristic = nil;
        _versionCharacteristic = nil;
        _service = nil;
        _RSSI = RSSI;
    }
    return self;
}

- (BOOL)isConnected {
    return (_peripheral.state == CBPeripheralStateConnected) &&
        (_controlPointCharacteristic != nil) && (_packetCharacteristic != nil) && (_versionCharacteristic != nil);
}

- (void)refresh {
    if( _peripheral.state == CBPeripheralStateConnected ) {
        if( _service == nil || _controlPointCharacteristic == nil || _packetCharacteristic == nil || _versionCharacteristic == nil ) {
            [_peripheral discoverServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:kDeviceDFUServiceUUID]]];
        }
    } else {
        _service = nil;
        _controlPointCharacteristic = nil;
        _packetCharacteristic = nil;
        _versionCharacteristic = nil;
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    _service = _peripheral.services[0];
    [_peripheral discoverCharacteristics:[NSArray arrayWithObjects:
                                          [CBUUID UUIDWithString:kDeviceControlPointCharacteristicUUID],
                                          [CBUUID UUIDWithString:kDevicePacketCharacteristicUUID],
                                          [CBUUID UUIDWithString:kDeviceVersionCharacteristicUUID], nil]
                              forService:_service];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for( int i = 0; i < service.characteristics.count; i++ ) {
        CBCharacteristic* characteristic = service.characteristics[i];
        if( [characteristic.UUID.UUIDString isEqualToString:kDeviceControlPointCharacteristicUUID] ) {
            _controlPointCharacteristic = characteristic;
        } else if( [characteristic.UUID.UUIDString isEqualToString:kDevicePacketCharacteristicUUID] ) {
            _packetCharacteristic = characteristic;
        } else if( [characteristic.UUID.UUIDString isEqualToString:kDeviceVersionCharacteristicUUID] ) {
            _versionCharacteristic = characteristic;
        }
    }
    if( _controlPointCharacteristic != nil && _packetCharacteristic != nil && _versionCharacteristic != nil ) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceConnectionNotification object:self];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if( error != nil ) {
        if( _versionCallback ) {
            void (^cb)(uint8_t major, uint8_t minor, NSError *error) = _versionCallback;
            _versionCallback = nil;
            cb(0, 0, nil);
        }
    } else if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:kDeviceVersionCharacteristicUUID]] ) {
        const uint8_t *version = [characteristic.value bytes];
        if( _versionCallback ) {
            void (^cb)(uint8_t major, uint8_t minor, NSError *error) = _versionCallback;
            _versionCallback = nil;
            cb(version[1], version[0], nil);
        }
        // what to do with this?
    } else {
    }
}

- (void)readVersion:(void (^)(uint8_t major, uint8_t minor, NSError *error))completed {
    _versionCallback = completed;
    [_peripheral readValueForCharacteristic:_versionCharacteristic];
}

- (void)_updateWithApplication:(NSString *)applicationFileName completed:(void (^)(NSError *))completed {
    // check the DFU version of the target
    [self readVersion:^(uint8_t major, uint8_t minor, NSError *error) {
        if( error != nil ) {
            if( completed != nil ) {
                completed(error);
            }
            return;
        }
        // check to see if we support the DFU version
        if( minor < 1 ) {
            if( completed != nil ) {
                completed([NSError errorWithDomain:@"DFU"
                                              code:0
                                          userInfo:@{NSLocalizedDescriptionKey: @"Unsupported DFU version."}]);
            }
            return;
        }
        // load up the firmware
        NDDFUFirmware* firmware = [[NDDFUFirmware alloc] initWithApplicationURL:[NSURL fileURLWithPath:applicationFileName]];
        if( ![firmware loadFileData:&error] ) {
            if( completed != nil ) {
                completed(error);
            }
            return;
        }
        // listen for packets from the control point
        [_peripheral setNotifyValue:YES forCharacteristic:_controlPointCharacteristic];
        // start the DFU
        uint8_t startDFURequest[] = {START_DFU_REQUEST, APPLICATION};
        [_peripheral writeValue:[NSData dataWithBytes:&startDFURequest length:sizeof(startDFURequest)]
              forCharacteristic:_controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
        // write the file size
        uint32_t fileSizeCollection[3] = { 0, 0, (uint32_t)firmware.data.length };
        [_peripheral writeValue:[NSData dataWithBytes:&fileSizeCollection length:sizeof(fileSizeCollection)]
                forCharacteristic:_packetCharacteristic type:CBCharacteristicWriteWithoutResponse];
        // we're done!
        if( completed != nil ) {
            completed(nil);
        }
    }];
}

- (void)updateWithApplication:(NSString*)applicationFileName completed:(void (^)(NSError* error))completed {
    if( self.isConnected ) {
        [self _updateWithApplication:applicationFileName completed:completed];
    } else {
        // connect to the device
        [_controller connect:self connected:^(NSError *error) {
            if( error != nil ) {
                if( completed != nil ) {
                    completed(error);
                }
            } else {
                [self _updateWithApplication:applicationFileName completed:completed];
            }
        }];
    }
}

@end
