//
//  main.m
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/12/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#include <stdio.h>
#import <Foundation/Foundation.h>
#import "NDDFUSampleController.h"
#import "NDDFUDevice.h"

int main(int argc, const char * argv[]) {
    if( argc < 2 ) {
        fprintf(stderr, "usage:\n\t%s <command>\ncommands:\n\tupdate <uuid> <application.bin>\n\tsamd21 <uuid> <application.bin>\n\tdiscover\n", argv[0]);
        return 1;
    }
    NDDFUSampleController* dfuController = [[NDDFUSampleController alloc] init];
    if( strcmp(argv[1], "update") == 0 ) {
        if( argc < 4 ) {
            fprintf(stderr, "error: missing uuid and application file name command line arguments.\n");
            return 1;
        }
        NSString* deviceUUID = [NSString stringWithUTF8String:argv[2]];
        NSString* applicationFileName = [NSString stringWithUTF8String:argv[3]];
        [dfuController updateWithApplication:applicationFileName uuid:deviceUUID
                                   completed:^(NSError *error) {
                                       if( error != nil ) {
                                           fprintf(stderr, "error: %s\n", [[error localizedDescription] UTF8String]);
                                           exit(1);
                                       } else {
                                           fprintf(stderr, "success!\n");
                                           exit(0);
                                       }
                                   }];
    } else if( strcmp(argv[1], "samd21") == 0 ) {
            if( argc < 4 ) {
                fprintf(stderr, "error: missing uuid and application file name command line arguments.\n");
                return 1;
            }
            NSString* deviceUUID = [NSString stringWithUTF8String:argv[2]];
            NSString* applicationFileName = [NSString stringWithUTF8String:argv[3]];
            [dfuController updateSamd21WithApplication:applicationFileName uuid:deviceUUID
                                       completed:^(NSError *error) {
                                           if( error != nil ) {
                                               fprintf(stderr, "error: %s\n", [[error localizedDescription] UTF8String]);
                                               exit(1);
                                           } else {
                                               fprintf(stderr, "success!\n");
                                               exit(0);
                                           }
                                       }];
    } else if( strcmp(argv[1], "discover")  == 0 ) {
        // wait a little bit
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for( int i = 0; i < dfuController.devices.count; i++ ) {
                NDDFUDevice* device = dfuController.devices[i];
                // only print out devices that have the DFU service (devices won't be able to be connected if they don't have the DFU service)
                if( device.isConnected ) {
                    fprintf(stdout, "%s[%s]\n", device.peripheral.name.UTF8String, device.peripheral.identifier.UUIDString.UTF8String);
                }
            }
            exit(0);
        });
        [dfuController discover];
    } else {
        fprintf(stderr, "error: unknown command '%s'\n", argv[1]);
        return 1;
    }        
    return 0;
}
