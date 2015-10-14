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
    NSDictionary* options = @{CBCentralManagerOptionShowPowerAlertKey:[NSNumber numberWithBool:YES]};
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
                                                      if( _devices.count > 0 ) {
                                                          if( uuid == nil ) {
                                                              device = _devices[0];
                                                          } else {
                                                              for( int i = 0; i < _devices.count; i++ ) {
                                                                  if( [[((NDDFUDevice*)_devices[i]).peripheral.identifier.UUIDString uppercaseString] isEqualToString:[uuid uppercaseString]] ) {
                                                                      device = _devices[i];
                                                                      break;
                                                                  }
                                                              }
                                                          }
                                                          [device updateWithApplication:applicationFileName completed:completed];
                                                      }
                                                  }];
    // wait a little bit
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
            completed(error);
        }
    });
    [[NSRunLoop currentRunLoop] run];
}

- (void)discover {    
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
                                                      object:self
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull note) {
                                                      if( device.isConnected ) {
                                                          connected(nil);
                                                      }
                                                  }];
    // connection timeout
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if( !device.isConnected ) {
            connected([NSError errorWithDomain:@"DFU"
                                          code:0
                                      userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"timed out connecting to device %@", device.peripheral.identifier.UUIDString]}]);
        }
    });
    [_centralManager connectPeripheral:device.peripheral
                               options:nil];
}

- (void)addDeviceForPeripheral:(CBPeripheral*)peripheral RSSI:(float)RSSI {
    [self willChangeValueForKey:@"devices"];
    NDDFUDevice* device = [[NDDFUDevice alloc] initWithPeripheral:peripheral RSSI:RSSI controller:self];
    _devices = [_devices arrayByAddingObject:device];
    [self didChangeValueForKey:@"devices"];
    [[NSNotificationCenter defaultCenter] postNotificationName:kDeviceDiscoveryNotification
                                                        object:self];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    // check if we've already seen this device, if so, update the signal strength
    for( NSUInteger i = 0; i < _devices.count; i++ ) {
        NDDFUDevice* device = _devices[i];
        if( [[device.peripheral identifier] isEqual:peripheral.identifier] ) {
            device.RSSI = [RSSI floatValue];
            return;
        }
    }
    [self addDeviceForPeripheral:peripheral RSSI:[RSSI floatValue]];
}

- (void)centralManager:(CBCentralManager *)central didRetrieveConnectedPeripherals:(NSArray *)peripherals {
}

- (void)centralManager:(CBCentralManager *)central didRetrievePeripherals:(NSArray *)peripherals {
    for( NSUInteger i = 0; i < peripherals.count; i++ ) {
        CBPeripheral* peripheral = peripherals[i];
        // check and see if we have this device yet
        bool found = false;
        for( NSUInteger j = 0; j < _devices.count; j++ ) {
            NDDFUDevice* device = _devices[i];
            if( [device.peripheral.identifier isEqual:peripheral.identifier] ) {
                found = true;
                break;
            }
        }
        // if we don't, then add it to our collection
        if( !found ) {
            [self addDeviceForPeripheral:peripheral RSSI:-100];
        }
    }
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if( central.state == CBCentralManagerStatePoweredOn ) {
        [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kDeviceDFUServiceUUID]]
                                                options:nil];
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
