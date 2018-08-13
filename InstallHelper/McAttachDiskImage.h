//
//  McAttachDiskImage.h
//  InstallHelper
//
//  Created by TanHao on 12-9-7.
//  Copyright (c) 2012年 http://www.tanhao.me. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface McAttachDiskImage : NSObject

+ (NSString *)mountDiskImageAtPath:(NSString *)path password:(NSString *)password error:(NSError **)error;
+ (BOOL)ejectAtPath:(NSString *)path;

@end
