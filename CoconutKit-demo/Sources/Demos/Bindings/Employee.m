//
//  Employee.m
//  CoconutKit-demo
//
//  Created by Samuel Défago on 16.07.13.
//  Copyright (c) 2013 Hortis. All rights reserved.
//

#import "Employee.h"

#import "DemoTransformer.h"

@implementation Employee

#pragma mark Class methods

+ (NSString *)stringFromNumber:(NSNumber *)number
{
    return [DemoTransformer stringFromNumber:number];
}

@end
