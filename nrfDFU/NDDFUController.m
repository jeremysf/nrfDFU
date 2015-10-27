//
//  NDDFUController.m
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/13/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#import "NDDFUController.h"
#import "NDDFUDevice.h"
#import "NDDFUFirmware.h"

NSString *const kDeviceDiscoveryNotification = @"kDeviceDiscoveryNotification";
NSString *const kDeviceDiscoveryDevice = @"kDeviceDiscoveryDevice";

@interface NDDFUController () {
    
}

@end


@implementation NDDFUController

@synthesize devices = _devices;
@synthesize centralManager = _centralManager;

- (id)init {
    self = [super init];
    if( self == nil ) {
        return nil;
    }
    _deviceToUpdate = nil;
    _deviceToUpdateUUID = nil;
    _devices = @[];
    return self;
}

- (void)dealloc {
    if( _centralManager != nil ) {
        _centralManager.delegate = nil;
    }
}

- (void)deviceConnected:(NDDFUDevice *)device {
    if( _deviceToUpdate != nil && _deviceToUpdateUUID != nil ) {
        _deviceToUpdateUUID = nil;
        [_deviceToUpdate startUpdateWithApplication:_firmware];
    }    
}

- (void)deviceError:(NDDFUDevice *)device error:(NSError*)error {
    if( _updateCompleteHandler != nil ) {
        _updateCompleteHandler(error);
        _updateCompleteHandler = nil;
    }
}

- (void)deviceUpdated:(NDDFUDevice *)device {
    if( _updateCompleteHandler != nil ) {
        _updateCompleteHandler(nil);
        _updateCompleteHandler = nil;
    }
}

- (void)deviceUpdateStatus:(NDDFUDevice*)device status:(NSString*)status {
    fprintf(stdout, "%s\n", [status UTF8String]);
}

- (void)deviceUpdateProgress:(NDDFUDevice*)device progress:(float)progress {
    fprintf(stdout, "%d/%d\n", (uint32_t)(progress * device.firmware.data.length), (uint32_t)device.firmware.data.length);
}


- (void)updateWithApplication:(NSString *)applicationFileName uuid:(NSString *)uuid completed:(void (^)(NSError* error))completed {
    NSError* error;
    _firmware = [[NDDFUFirmware alloc] initWithApplicationURL:[NSURL fileURLWithPath:applicationFileName]];
    if( ![_firmware loadFileData:&error] ) {
        completed(error);
        return;
    }
    _updateCompleteHandler = completed;
    _deviceToUpdateUUID = uuid;
    // start discovering devices
    [self initCentralManager];
    // allow for 5 second timeout finding the device
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if( _deviceToUpdate == nil ) {
            NSError* error = nil;
            if( uuid == nil ) {
                error = [NSError errorWithDomain:@"DFU"
                                            code:0
                                        userInfo:@{NSLocalizedDescriptionKey: @"Unable to find device to update."}];
            } else {
                error = [NSError errorWithDomain:@"DFU"
                                            code:0
                                        userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Unable to find device '%@'", [NSString stringWithFormat:@"Unable to find device '%@'", uuid]]}];
            }
            if( completed != nil ) {
                _updateCompleteHandler = nil;
                completed(error);
            }
        }
    });
    CFRunLoopRun();
}

- (void)discover {
    // start discovering devices
    [self initCentralManager];
    dispatch_main();
}

- (void)initCentralManager {
    NSDictionary* options = @{CBCentralManagerOptionShowPowerAlertKey:[NSNumber numberWithBool:NO]};
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                           queue:nil
                                                         options:options];
}

- (NDDFUDevice*)deviceForPeripheral:(CBPeripheral*)peripheral {
    for( NSUInteger i = 0; i < _devices.count; i++ ) {
        NDDFUDevice* device = _devices[i];
        if( device.peripheral == peripheral ) {
            return device;
        }
    }
    return nil;
}

- (NDDFUDevice*)addDeviceForPeripheral:(CBPeripheral*)peripheral RSSI:(float)RSSI {
    [self willChangeValueForKey:@"devices"];
    NDDFUDevice* device = [[NDDFUDevice alloc] initWithPeripheral:peripheral RSSI:RSSI controller:self];
    device.delegate = self;
    _devices = [_devices arrayByAddingObject:device];
    [self didChangeValueForKey:@"devices"];
    return device;
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NDDFUDevice* device = [self deviceForPeripheral:peripheral];
    [device onPeripheralConnected:central];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NDDFUDevice* device = [self deviceForPeripheral:peripheral];
    [device onPeripheralDisconnected:central];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    // don't care as this will get caught by the timeout
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    // check if we've already seen this device, if so, update the signal strength
    for( NSUInteger i = 0; i < _devices.count; i++ ) {
        NDDFUDevice* device = _devices[i];
        if( [[device.peripheral identifier] isEqual:peripheral.identifier] ) {
            if( RSSI != nil) {
                device.RSSI = [RSSI floatValue];
            }
            return;
        }
    }
    // otherwise add this device
    NDDFUDevice* device = [self addDeviceForPeripheral:peripheral RSSI:[RSSI floatValue]];
    if( _deviceToUpdateUUID != nil ) {
        if( [[device.peripheral.identifier.UUIDString uppercaseString] isEqualToString:[_deviceToUpdateUUID uppercaseString]] ) {
            _deviceToUpdate = device;
            [_centralManager connectPeripheral:device.peripheral
                                       options:nil];
        }
    } else {
        [_centralManager connectPeripheral:device.peripheral
                                   options:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals {
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals {
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if( central.state == CBCentralManagerStatePoweredOn ) {
        // can't scan for peripherals with the service because the service is not advertised
        [_centralManager scanForPeripheralsWithServices:nil //@[[CBUUID UUIDWithString:kDeviceDFUServiceUUID]]
                                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
    } else {
        [_centralManager stopScan];
        [self willChangeValueForKey:@"devices"];
        _devices = @[];
        [self didChangeValueForKey:@"device"];
    }
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict {
}

@end
