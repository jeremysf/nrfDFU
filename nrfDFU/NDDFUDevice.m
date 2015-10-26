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

@interface NDDFUDevice () {
    void (^_versionCallback)(uint8_t major, uint8_t minor, NSError *error);
}

@end

@implementation NDDFUDevice

@synthesize peripheral = _peripheral;
@synthesize RSSI = _RSSI;
@synthesize versionMajor = _versionMajor;
@synthesize versionMinor = _versionMinor;
@synthesize delegate = _delegate;

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
        _versionMajor = 0;
        _versionMinor = 0;
        _delegate = nil;
        _state = STATE_IDLE;
    }
    return self;
}

- (void)dealloc {
    _peripheral.delegate = nil;
    _peripheral = nil;
}

- (BOOL)isConnected {
    return (_peripheral.state == CBPeripheralStateConnected) &&
        (_controlPointCharacteristic != nil) && (_packetCharacteristic != nil) && (_versionCharacteristic != nil);
}

- (void)onPeripheralConnected:(CBCentralManager*)manager {
    fprintf(stdout, "connecting...\n");
    if( _service == nil || _controlPointCharacteristic == nil || _packetCharacteristic == nil || _versionCharacteristic == nil ) {
        [_peripheral discoverServices:[NSArray arrayWithObject:[CBUUID UUIDWithString:kDeviceDFUServiceUUID]]];
    }
}

- (void)onPeripheralDisconnected:(CBCentralManager*)manager {
    fprintf(stdout, "disconnecting...\n");
    _service = nil;
    _controlPointCharacteristic = nil;
    _packetCharacteristic = nil;
    _versionCharacteristic = nil;
    _versionMajor = 0;
    _versionMinor = 0;
    // potentially attempt to reconnect
    if( _state == STATE_ENTERING_BOOTLOADER ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [manager connectPeripheral:_peripheral options:nil];
        });
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
        if( _state == STATE_ENTERING_BOOTLOADER ) {
            // after regaining connection, query the version to see
            //  if we successfully entered the bootloader
            [self _queryVersion];
        } else if( _state != STATE_IDLE ){
            // we're reconnecting during the middle of the update process
        } else {
            if( _delegate != nil ) {
                [_delegate deviceConnected:self];
            }
        }
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
        _versionCallback = nil;
        _versionMajor = version[1];
        _versionMinor = version[0];
        if( _versionMinor == 1 ) {
            // if the version is 1, then we are in the app, we need
            //  to restart into the bootloader
            [self _restartIntoBootloader];
        } else {
            // if the version is not 1, then we are in the bootloader, so
            //  we'll start the DFU process
            [self _startDFURequest];
        }
    } else {
        const uint8_t* response = [characteristic.value bytes];
        [self _handleDeviceResponse:response[0]
                      requestedCode:response[1]
                     responseStatus:response[2]];
    }
}

- (void)_queryVersion {
    // kick off the update by reading the version
    [_peripheral readValueForCharacteristic:_versionCharacteristic];
    _state = STATE_QUERYING_VERSION;
}

- (void)_restartIntoBootloader {
    // listen for packets from the control point
    [_peripheral setNotifyValue:YES forCharacteristic:_controlPointCharacteristic];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        fprintf(stdout, "restarting into bootloader...\n");
        // basically restart the device into DFU mode
        uint8_t startDFURequest[] = {START_DFU_REQUEST, APPLICATION };
        [_peripheral writeValue:[NSData dataWithBytes:startDFURequest length:sizeof(startDFURequest)]
              forCharacteristic:_controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
        _state = STATE_ENTERING_BOOTLOADER;
    });
}

- (void)_startDFURequest {
    // listen for packets from the control point
    [_peripheral setNotifyValue:YES forCharacteristic:_controlPointCharacteristic];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // start the DFU
        uint8_t startDFURequest[] = {START_DFU_REQUEST, APPLICATION};
        [_peripheral writeValue:[NSData dataWithBytes:startDFURequest length:sizeof(startDFURequest)]
              forCharacteristic:_controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
        // write the file size
        uint32_t fileSizeCollection[3] = { 0, 0, (uint32_t)_firmware.data.length };
        [_peripheral writeValue:[NSData dataWithBytes:fileSizeCollection length:sizeof(fileSizeCollection)]
              forCharacteristic:_packetCharacteristic type:CBCharacteristicWriteWithoutResponse];
        _state = STATE_STARTING_UPDATE;
    });
}

- (void)_sendInitPacket {
    struct init_packet_t {
        uint16_t deviceType, deviceRevision;
        uint32_t applicationVersion;
        uint16_t softDeviceCount, softDeviceVersion;
        uint16_t crc;
    } init_packet = { 0, 0, 0, 1, 0x0064, [_firmware crc] };
    uint8_t initPacketStart[] = {INITIALIZE_DFU_PARAMETERS_REQUEST, START_INIT_PACKET};
    [_peripheral writeValue:[NSData dataWithBytes:initPacketStart length:sizeof(initPacketStart)] forCharacteristic:_controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
    [_peripheral writeValue:[NSData dataWithBytes:&init_packet length:sizeof(init_packet)] forCharacteristic:_packetCharacteristic type:CBCharacteristicWriteWithoutResponse];
    uint8_t initPacketEnd[] = {INITIALIZE_DFU_PARAMETERS_REQUEST, END_INIT_PACKET};
    [_peripheral writeValue:[NSData dataWithBytes:initPacketEnd length:sizeof(initPacketEnd)] forCharacteristic:_controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
}

- (void)_startSendingFirmware {
    uint8_t value[] = {PACKET_RECEIPT_NOTIFICATION_REQUEST, PACKETS_NOTIFICATION_INTERVAL, 0};
    [_peripheral writeValue:[NSData dataWithBytes:value length:sizeof(value)] forCharacteristic:_controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
    uint8_t value2 = RECEIVE_FIRMWARE_IMAGE_REQUEST;
    [_peripheral writeValue:[NSData dataWithBytes:&value2 length:sizeof(value2)] forCharacteristic:_controlPointCharacteristic type:CBCharacteristicWriteWithResponse];
    // TODO: only send PACKETS_NOTIFICATION_INTERVAL packets at a time
    for( uint32_t i = 0; i < _firmware.data.length / 20; i++ ) {
        [_peripheral writeValue:[_firmware.data subdataWithRange:NSMakeRange(i * 20, 20)] forCharacteristic:_packetCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
    if( (_firmware.data.length % 20) != 0 ) {
        [_peripheral writeValue:[_firmware.data subdataWithRange:NSMakeRange(((uint32_t)(_firmware.data.length / 20)) * 20, _firmware.data.length % 20)] forCharacteristic:_packetCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
}

- (void)_handleDeviceResponse:(uint8_t)responseCode requestedCode:(uint8_t)requestedCode responseStatus:(uint8_t)responseStatus {
    if( responseCode == RESPONSE_CODE ) {
        switch( requestedCode ) {
            case START_DFU_REQUEST:
                switch (responseStatus) {
                    case OPERATION_SUCCESSFUL_RESPONSE:
                        [self _sendInitPacket];
                        break;
                    case OPERATION_NOT_SUPPORTED_RESPONSE:
                        //[dfuDelegate onError:errorMessage];
                        //[dfuRequests resetSystem];
                        break;
                    default:
                        //[dfuDelegate onError:errorMessage];
                        //[dfuRequests resetSystem];
                        break;
                }
                break;
            case RECEIVE_FIRMWARE_IMAGE_REQUEST:
                //[self processReceiveFirmwareResponseStatus];
                break;
            case VALIDATE_FIRMWARE_REQUEST:
                //[self processValidateFirmwareResponseStatus];
                break;
            case INITIALIZE_DFU_PARAMETERS_REQUEST:
                [self _startSendingFirmware];
                break;
        }
    } else if( responseCode == PACKET_RECEIPT_NOTIFICATION_RESPONSE ) {
        // should send the next PACKETS_NOTIFICATION_INTERVAL number of packets
    }
}

- (void)startUpdateWithApplication:(NDDFUFirmware*)firmware {
    _firmware = firmware;
    // query the version, if the app is running and not the bootloader, this will result
    //  in entering the bootloader, if we're already in the bootloader, this will result in the
    //  DFU process starting
    [self _queryVersion];
}

@end
