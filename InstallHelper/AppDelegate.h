//
//  AppDelegate.h
//  InstallHelper
//
//  Created by TanHao on 12-9-6.
//  Copyright (c) 2012年 tanhao.me. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    IBOutlet NSTextField   *titleField;
}

@property (assign) IBOutlet NSWindow *window;

@end
