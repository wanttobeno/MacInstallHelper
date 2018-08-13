//
//  AppDelegate.m
//  InstallHelper
//
//  Created by TanHao on 12-9-6.
//  Copyright (c) 2012年 http://www.tanhao.me. All rights reserved.
//

#import "AppDelegate.h"
#import "McInstallHelper.h"

@implementation AppDelegate
@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{

}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
	if (!flag)
    {
		[self.window makeKeyAndOrderFront:self];
	}
	return YES;
}

- (void)dragFileEnter:(NSString *)aFilePath
{
    NSString *fileName = [aFilePath lastPathComponent];
    
    NSString *titleString = [NSString stringWithFormat:@"正在安装:%@ ...",fileName];
    [titleField setStringValue:titleString];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        McInstallHelper *helper = [[McInstallHelper alloc] init];
        BOOL flag = [helper installWithPath:aFilePath];
        [titleField setStringValue:flag?@"安装成功":@"安装失败"];
    });
}

@end
