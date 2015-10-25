//
//  main.m
//  nrfDFU
//
//  Created by Jeremy Gordon on 10/12/15.
//  Copyright © 2015 Superstructure. All rights reserved.
//

#include <stdio.h>
#import <Foundation/Foundation.h>
#import "NDDFUController.h"
#import "NDDFUDevice.h"

int main(int argc, const char * argv[]) {
    if( argc < 2 ) {
        fprintf(stderr, "usage:\n\t%s <command>\ncommands:\n\tupdate <uuid> <application.hex>\n\tdiscover\n", argv[0]);
        return 1;
    }
    NDDFUController* dfuController = [[NDDFUController alloc] init];
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
                                           exit(0);
                                       }
                                   }];
    } else if( strcmp(argv[1], "discover")  == 0 ) {
        // wait a little bit
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for( int i = 0; i < dfuController.devices.count; i++ ) {
                NDDFUDevice* device = dfuController.devices[i];
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
