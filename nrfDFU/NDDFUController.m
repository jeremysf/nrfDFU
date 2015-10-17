//
//  NDDFUController.m
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/13/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#import "NDDFUController.h"
#import "NDDFUDevice.h"

NSString *const kDeviceDiscoveryNotification = @"kDeviceDiscoveryNotification";
NSString *const kDeviceDiscoveryDevice = @"kDeviceDiscoveryDevice";

@interface NDDFUController () {
    
}

@end


@implementation NDDFUController

@synthesize devices = _devices;

- (id)init {
    self = [super init];
    if( self == nil ) {
        return nil;
    }
    _devices = @[];
    NSDictionary* options = @{CBCentralManagerOptionShowPowerAlertKey:[NSNumber numberWithBool:NO]};
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                           queue:nil
                                                         options:options];
    return self;
}

- (void)updateWithApplication:(NSString *)applicationFileName uuid:(NSString *)uuid completed:(void (^)(NSError* error))completed {
    __block NDDFUDevice* device = nil;
    [[NSNotificationCenter defaultCenter] addObserverForName:kDeviceDiscoveryNotification
                                                      object:self
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull note) {
                                                      if( device == nil ) {
                                                          NDDFUDevice* candidateDevice = note.userInfo[kDeviceDiscoveryDevice];
                                                          if( uuid != nil && [[candidateDevice.peripheral.identifier.UUIDString uppercaseString] isEqualToString:[uuid uppercaseString]] ) {
                                                              // if the user specified a uuid and we found it, let's update it!
                                                              device = candidateDevice;
                                                              [device updateWithApplication:applicationFileName completed:completed];
                                                          } else {
                                                              // if the user didn't specify a uuid, we need to connect to it and see if it supports the DFU service
                                                              [self connect:candidateDevice
                                                                  connected:^(NSError *error) {
                                                                      if( error == nil && device == nil ) {
                                                                          device = candidateDevice;
                                                                          [device updateWithApplication:applicationFileName completed:completed];
                                                                      }
                                                                  }];
                                                          }
                                                      }
                                                  }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // allow for 15 second timeout finding the device
        if( device == nil ) {
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
                completed(error);
            }
        }
    });
    [[NSRunLoop currentRunLoop] run];
}

- (void)discover {
    [[NSNotificationCenter defaultCenter] addObserverForName:kDeviceDiscoveryNotification
                                                      object:self
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull note) {
                                                      NDDFUDevice* device = note.userInfo[kDeviceDiscoveryDevice];
                                                      [self connect:device connected:nil];
                                                  }];
    
    [[NSRunLoop currentRunLoop] run];
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

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NDDFUDevice* device = [self deviceForPeripheral:peripheral];
    [device refresh];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NDDFUDevice* device = [self deviceForPeripheral:peripheral];
    [device refresh];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
}

- (void)connect:(NDDFUDevice*)device connected:(void (^)(NSError* error))connected {
    // wait for connection
    [[NSNotificationCenter defaultCenter] addObserverForName:kDeviceConnectionNotification
                                                      object:device
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull note) {
                                                      if( device.isConnected && connected != nil ) {
                                                          connected(nil);
                                                      }
                                                  }];
    // connection timeout
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if( !device.isConnected && connected != nil ) {
            connected([NSError errorWithDomain:@"DFU"
                                          code:0
                                      userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"timed out connecting to device %@", device.peripheral.identifier.UUIDString]}]);
        }
    });
    [_centralManager connectPeripheral:device.peripheral
                               options:nil];
}

- (NDDFUDevice*)addDeviceForPeripheral:(CBPeripheral*)peripheral RSSI:(float)RSSI {
    [self willChangeValueForKey:@"devices"];
    NDDFUDevice* device = [[NDDFUDevice alloc] initWithPeripheral:peripheral RSSI:RSSI controller:self];
    _devices = [_devices arrayByAddingObject:device];
    [self didChangeValueForKey:@"devices"];
    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceDiscoveryNotification
                                                        object:self
                                                      userInfo:@{kDeviceDiscoveryDevice:device}];
    return device;
     
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
    [self addDeviceForPeripheral:peripheral RSSI:[RSSI floatValue]];
}

- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals {
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals {
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if( central.state == CBCentralManagerStatePoweredOn ) {
        // can't scan for peripherals with the service because the service is not advertised
        [_centralManager scanForPeripheralsWithServices:nil //@[[CBUUID UUIDWithString:kDeviceDFUServiceUUID]]
                                                options:@{CBCentralManagerScanOptionAllowDuplicatesKey:[NSNumber numberWithBool:NO]}];
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
