//
//  VirtualSteeringWheel.m
//  Hoverpad
//
//  Created by Peter James Bernante on 1/12/17.
//  Copyright © 2017 Robby Kraft. All rights reserved.
//

#import "VirtualSteeringWheel.h"
#include <IOKit/IOKitLib.h>

#define SERVICE_NAME "it_unbit_foohid"

#define FOOHID_CREATE  0  // create selector
#define FOOHID_DESTROY 1 //
#define FOOHID_SEND    2  // send selector
#define FOOHID_LIST    3

#define DEVICE_NAME "FooHID Virtual Steering Wheel"
#define DEVICE_SN "SN 789012"

#define SEND_COUNT 4

unsigned char report_descriptor[] = {
    0x05, 0x01,                    // USAGE_PAGE (Generic Desktop)
    0x09, 0x05,                    // USAGE (Game Pad)
    0xa1, 0x01,                    // COLLECTION (Application)
    0xa1, 0x00,                    //   COLLECTION (Physical)
    0x05, 0x09,                    //     USAGE_PAGE (Button)
    0x19, 0x01,                    //     USAGE_MINIMUM (Button 1)
    0x29, 0x10,                    //     USAGE_MAXIMUM (Button 16)
    0x15, 0x00,                    //     LOGICAL_MINIMUM (0)
    0x25, 0x01,                    //     LOGICAL_MAXIMUM (1)
    0x95, 0x10,                    //     REPORT_COUNT (16)
    0x75, 0x01,                    //     REPORT_SIZE (1)
    0x81, 0x02,                    //     INPUT (Data,Var,Abs)
    0x05, 0x01,                    //     USAGE_PAGE (Generic Desktop)
    0x09, 0x30,                    //     USAGE (X)
    0x09, 0x31,                    //     USAGE (Y)
    0x09, 0x32,                    //     USAGE (Z)
    0x09, 0x33,                    //     USAGE (Rx)
    0x15, 0x81,                    //     LOGICAL_MINIMUM (-127)
    0x25, 0x7f,                    //     LOGICAL_MAXIMUM (127)
    0x75, 0x08,                    //     REPORT_SIZE (8)
    0x95, 0x04,                    //     REPORT_COUNT (4)
    0x81, 0x02,                    //     INPUT (Data,Var,Abs)
    0xc0,                          //   END_COLLECTION
    0xc0                           // END_COLLECTION
};

struct gamepad_report_t {
    uint16_t buttons;
    int8_t left_x;
    int8_t left_y;
    int8_t right_x;
    int8_t right_y;
};

@interface VirtualSteeringWheel () {
    char	*_deviceName;
    io_connect_t connect;
    BOOL isConnected;
    
    struct gamepad_report_t gamepad;
    uint64_t send_message[SEND_COUNT];
}

@end


@implementation VirtualSteeringWheel

-(id) init{
    self = [super init];
    if(self){
        _deviceName = strdup(DEVICE_NAME);
        isConnected = false;
        
        gamepad.buttons = 0;
        gamepad.left_x = 0;
        gamepad.left_y = 0;
        gamepad.right_x = 0;
        gamepad.right_y = 0;
    }
    return self;
}

-(BOOL) connectDevice {
    
    if (isConnected) {
        NSLog(@"Virtual steering wheel is already connected.");
        return true;
    }
    
    io_iterator_t iterator;
    io_service_t service;
    
    // Get a reference to the IOService
    kern_return_t ret = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(SERVICE_NAME), &iterator);
    
    if (ret != KERN_SUCCESS) {
        NSLog(@"Unable to access IOService.");
        return false;
    }
    
    
    // Iterate till success
    int found = 0;
    while ((service = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
        ret = IOServiceOpen(service, mach_task_self(), 0, &self->connect);
        
        if (ret == KERN_SUCCESS) {
            found = 1;
            IOObjectRelease(service);
            break;
        }
        
        IOObjectRelease(service);
    }
    IOObjectRelease(iterator);
    
    if (!found) {
        NSLog(@"Unable to open IOService.");
        return false;
    }
    
    isConnected = true;
    
    
    // Fill up the input arguments.
    uint32_t input_count = 8;
    uint64_t input[input_count];
    input[0] = (uint64_t) self->_deviceName;  // device name
    input[1] = strlen((char *)input[0]);  // name length
    input[2] = (uint64_t) report_descriptor;  // report descriptor
    input[3] = sizeof(report_descriptor);  // report descriptor len
    input[4] = (uint64_t) strdup(DEVICE_SN);  // serial number
    input[5] = strlen((char *)input[4]);  // serial number len
    input[6] = (uint64_t) 2;  // vendor ID
    input[7] = (uint64_t) 3;  // device ID
    
    ret = IOConnectCallScalarMethod(self->connect, FOOHID_CREATE, input, input_count, NULL, 0);
    if (ret != KERN_SUCCESS) {
        NSLog(@"Unable to create HID device. May be fine if created previously.");
    }
    
    // Arguments to be passed through the HID message.
    self->send_message[0] = (uint64_t) self->_deviceName;  // device name
    self->send_message[1] = strlen((char *) self->send_message[0]);  // name length
    self->send_message[2] = (uint64_t) &self->gamepad;  // gamepad struct
    self->send_message[3] = sizeof(struct gamepad_report_t);  // gampad struct len
    
    
    NSLog(@"Virtual steering wheel connected.");
    return true;
}


-(BOOL) disconnectDevice {
    if (!isConnected) return true;
    
    uint32_t remove_message_count = 2;
    uint64_t remove_message[remove_message_count];
    remove_message[0] = (uint64_t) self->_deviceName;   // name pointer
    remove_message[1] = strlen((char *)remove_message[0]);;      // name length
    
    kern_return_t ret = IOConnectCallScalarMethod(self->connect, FOOHID_DESTROY, remove_message, remove_message_count, NULL, 0);
    if (ret != KERN_SUCCESS) {
        printf("Unable to remove HID device.");
        return false;
    }
    
    isConnected = false;
    
    NSLog(@"Successfully removed HID device.");
    return true;
}

-(void) sendMessage:(NSData*)encodedData {
    
    kern_return_t ret = IOConnectCallScalarMethod(self->connect,
                                                  FOOHID_SEND,
                                                  self->send_message,
                                                  SEND_COUNT,
                                                  NULL, 0);
    if (ret != KERN_SUCCESS) {
        NSLog(@"Unable to send message to HID device");
    }
}

-(void) sendLeftX: (float) leftX leftY: (float) leftY rightX: (float) rightX rightY: (float) rightY {
    if (!self->isConnected) {
        NSLog(@"Device is not connected.");
        return;
    }
    
//    NSLog(@"(%f, %f) (%f, %f)",
//          [self clipCoordinateTo: leftX],
//          [self clipCoordinateTo: leftY],
//          [self clipCoordinateTo: rightX],
//          [self clipCoordinateTo: rightY]);
    
    self->gamepad.left_x = [self clipCoordinateTo: leftX];
    self->gamepad.left_y = [self clipCoordinateTo: leftY];
    self->gamepad.right_x = [self clipCoordinateTo: rightX];
    self->gamepad.right_y = [self clipCoordinateTo: rightY];
    
    kern_return_t ret = IOConnectCallScalarMethod(self->connect,
                                                  FOOHID_SEND,
                                                  self->send_message,
                                                  SEND_COUNT,
                                                  NULL, 0);
    if (ret != KERN_SUCCESS) {
        NSLog(@"Unable to send message to HID device");
    }
}

- (float)clipCoordinateTo:(float)value
{
    value *= 127.0f;
    
    if(value < -127.0f)
        value = -127.0f;
    
    if(value > 127.0f)
        value = 127.0f;
    
    return value;
}

-(void) dealloc{
    [self disconnectDevice];
    free(_deviceName);
}

@end
