//
//  VirtualSteeringWheel.h
//  Hoverpad
//
//  Created by Peter James Bernante on 1/12/17.
//  Copyright © 2017 Robby Kraft. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VirtualSteeringWheel : NSObject

-(BOOL) connectDevice;
-(BOOL) disconnectDevice;

-(void) sendLeftX: (float) leftX leftY: (float) leftY rightX: (float) rightX rightY: (float) rightY;

@end