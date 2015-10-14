//
//  NDDFUDevice.m
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/13/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#import "NDDFUDevice.h"
#import "NDDFUController.h"

NSString *const kDeviceDFUServiceUUID = @"00001530-1212-EFDE-1523-785FEABCD123";
NSString *const kDeviceControlPointCharacteristicUUID = @"00001531-1212-EFDE-1523-785FEABCD123";
NSString *const kDevicePacketCharacteristicUUID = @"00001532-1212-EFDE-1523-785FEABCD123";
NSString *const kDeviceVersionCharacteristicUUID = @"00001534-1212-EFDE-1523-785FEABCD123";

NSString *const kDeviceConnectionNotification = @"kDeviceConnectionNotification";

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

- (void)updateWithApplication:(NSString*)applicationFileName completed:(void (^)(NSError* error))completed {
    // connect to the device
    [_controller connect:self connected:^(NSError *error) {
        if( error != nil ) {
            completed(error);
        } else {
            // TODO: perform the update!
        }
    }];
}

@end
