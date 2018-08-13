//
//  McAttachDiskImage.m
//  InstallHelper
//
//  Created by TanHao on 12-9-7.
//  Copyright (c) 2012年 http://www.tanhao.me. All rights reserved.
//

#import "McAttachDiskImage.h"
#import <SecurityFoundation/SFAuthorization.h>

@implementation McAttachDiskImage

+ (NSTask *)hdiutilTaskWithCommand:(NSString *)command path:(NSString *)path options:(NSArray *)options password:(NSString *)password
{
	NSTask *newTask;
	NSFileHandle *stdinHandle;
	
	newTask = [[NSTask alloc] init];
	[newTask setLaunchPath:@"/usr/bin/hdiutil"];
	
	NSMutableArray *arguments = [NSMutableArray arrayWithObject:command];
	[arguments addObject:path];
    if (options)
    {
        [arguments addObjectsFromArray:options];
    }
	
	[newTask setStandardOutput:[NSPipe pipe]];
	[newTask setStandardError:[NSPipe pipe]];
	[newTask setStandardInput:[NSPipe pipe]];
	
	if (password) {
		stdinHandle = [[newTask standardInput] fileHandleForWriting];
		[stdinHandle writeData:[password dataUsingEncoding:NSUTF8StringEncoding]];
		[stdinHandle writeData:[NSData dataWithBytes:"" length:1]];
		
		[arguments addObject:@"-stdinpass"];
	}
	
	[newTask setArguments:arguments];
    
	return newTask;
}

+ (BOOL)getDiskImagePropertyList:(id *)outPlist atPath:(NSString *)path command:(NSString *)command options:(NSArray *)options password:(NSString *)password error:(NSError **)outError
{
	BOOL retval = YES;
	NSMutableDictionary *info;
	NSString *failureReason;
	NSData *outputData;
	NSTask *newTask;
    
    NSMutableArray *arguments = [NSMutableArray arrayWithObject:@"-plist"];
    if (options)
    {
        [arguments addObjectsFromArray:options];
    }
	newTask = [self hdiutilTaskWithCommand:command path:path options:arguments password:password];
	[newTask launch];
	[newTask waitUntilExit];
    
	outputData = [[[newTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    
	if ([newTask terminationStatus] == 0) {
		*outPlist = [NSPropertyListSerialization propertyListFromData:outputData
													 mutabilityOption:NSPropertyListImmutable
															   format:NULL
													 errorDescription:&failureReason];
		
		if (!*outPlist) {
			failureReason = NSLocalizedString(@"hdiutil output is not a property list.", nil);
			retval = NO;
		}
	}
	else {
		failureReason = NSLocalizedString(@"hdiutil ended abnormally.", nil);
		retval = NO;
	}
	
	if (retval == NO && *outError) {
		info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				NSLocalizedString(@"Error executing hdiutil command", nil), NSLocalizedDescriptionKey,
				failureReason, NSLocalizedFailureReasonErrorKey,
				failureReason, NSLocalizedRecoverySuggestionErrorKey,
				nil];
		*outError = [NSError errorWithDomain:@"AppErrorDomain" code:-1 userInfo:info];
	}
	
	return retval;
}

+ (BOOL)getDiskImageEncryptionStatus:(BOOL *)outFlag atPath:(NSString *)path error:(NSError **)outError
{
	BOOL isOK = YES;
	NSMutableDictionary *plist;
	id value;
	
	isOK = [self getDiskImagePropertyList:&plist atPath:path command:@"isencrypted" options:nil password:nil error:outError];
	if (isOK) {
		value = [plist objectForKey:@"encrypted"];
		if (value) {
			*outFlag = [value boolValue];
		}
		else {
			NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										 NSLocalizedString(@"Failed to get encryption property", nil), NSLocalizedDescriptionKey,
										 NSLocalizedString(@"Check that \"/usr/bin/hdiutil isencrypted\" is functioning correctly.", nil),
										 NSLocalizedRecoverySuggestionErrorKey,
										 nil];
			*outError = [NSError errorWithDomain:@"AppErrorDomain" code:-1 userInfo:info];
			isOK = NO;
		}
	}
    
	return isOK;
}

+ (BOOL)getDiskImageSLAStatus:(BOOL *)outFlag atPath:(NSString *)path password:(NSString *)password error:(NSError **)outError
{
	BOOL isOK = YES;
	NSMutableDictionary *plist;
	
	isOK = [self getDiskImagePropertyList:&plist atPath:path command:@"imageinfo" options:nil password:password error:outError];
	if (isOK) {
		id value = [plist valueForKeyPath:@"Properties.Software License Agreement"];
		if (value) {
			*outFlag = [value boolValue];
		}
		else if (*outError) {
			NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										 NSLocalizedString(@"Failed to get SLA property", nil), NSLocalizedDescriptionKey,
										 NSLocalizedString(@"Check that \"/usr/bin/hdiutil imageinfo\" is functioning correctly.", nil),
										 NSLocalizedRecoverySuggestionErrorKey,
										 nil];
			*outError = [NSError errorWithDomain:@"AppErrorDomain" code:-1 userInfo:info];
			isOK = NO;
		}
	}
	return isOK;
}

+ (BOOL)attachDiskImageAtPath:(NSString *)path options:(NSArray *)options password:(NSString *)password error:(NSError **)outError mountPoint:(NSString **)mountPoint
{
	BOOL isEncrypted, hasSLA;
    
	if (!password)
    {
        //判断DMG是否已经加密
		if ([self getDiskImageEncryptionStatus:&isEncrypted atPath:path error:outError])
        {
			if (isEncrypted)
            {
                //弹出窗口让用户输入密码
				password = [self promptUserForPasswordAtPath:path error:outError];
				if (!password)
                {
                    return NO;
                }
			}
		}
		else
        {
			return NO; // get encryption status failed
		}
	}
	
    //判断是否有Software License Agreement
	if ([self getDiskImageSLAStatus:&hasSLA atPath:path password:password error:outError] == NO)
    {
        return NO;
    }
	
    NSMutableDictionary *plist = nil;
    BOOL rel = [self getDiskImagePropertyList:&plist atPath:path command:@"attach" options:options password:password error:outError];
    if (!rel && !plist)
    {
        return NO;
    }
    
    NSString *pointPath = nil;
    NSArray *systemEntities = [plist objectForKey:@"system-entities"];
    for (NSDictionary *entity in systemEntities)
    {
        NSString *mountValue = [entity objectForKey:@"mount-point"];
        if (mountValue)
        {
            pointPath = mountValue;
            break;
        }
    }
    
    if (pointPath)
    {
        *mountPoint = pointPath;
        return YES;
    }
    return NO;
}

#pragma mark -
#pragma mark Public Method

+ (NSString *)mountDiskImageAtPath:(NSString *)path password:(NSString *)password error:(NSError **)error
{
	NSMutableArray *attachOptions = [NSMutableArray array];
    
    //在Finder中无显示
    [attachOptions addObject:@"-nobrowse"];
    
    //打印显示进度
    //[attachOptions addObject:@"-puppetstrings"];
    
    //开启只读
    //[attachOptions addObject:@"-readonly"];
    
    //是否验证
    //[attachOptions addObject:@"-noverify"];
    //[attachOptions addObject:@"-verify"];
    
    NSString *mountPoint = nil;
    BOOL isOK = [self attachDiskImageAtPath:path options:attachOptions password:password error:error mountPoint:&mountPoint];
    if (!isOK || !mountPoint)
    {
        return nil;
    }
    return mountPoint;
}

+ (BOOL)ejectAtPath:(NSString *)path
{
    NSMutableArray *arguments = [NSMutableArray array];//unmount
    NSTask *newTask = [self hdiutilTaskWithCommand:@"eject" path:path options:arguments password:nil];
    
    NSFileHandle *file = [newTask.standardError fileHandleForReading];
    [newTask launch];
    [newTask waitUntilExit];
    
    if ([newTask terminationStatus] != 0)
    {
        return NO;
    }
    
    NSData *data = [file readDataToEndOfFile];
    if ([data length]>0)
        return NO;
    else
        return YES;
}

#pragma mark -
#pragma mark Prompt User For Password

+ (NSString *)promptUserForPasswordAtPath:(NSString *)path error:(NSError **)outError
{
	SFAuthorization *authorization;
	AuthorizationRights rights;
	AuthorizationEnvironment env;
	AuthorizationFlags flags;
	AuthorizationItemSet *info;
	OSStatus status;
	NSString *password;
	
	NSString *fileName = [path lastPathComponent];
	NSString *prompt = [NSString stringWithFormat:NSLocalizedString(@"Enter password to access %@", nil), fileName];
	
	AuthorizationItem rightsItems[1] = { { "com.apple.builtin.generic-unlock", 0, NULL, 0 } };
	rights.count = sizeof(rightsItems) / sizeof(AuthorizationItem);;
	rights.items = rightsItems;
    
	AuthorizationItem envItems[1] = {
		{ kAuthorizationEnvironmentPrompt, strlen([prompt UTF8String]), (void *)[prompt UTF8String], 0 }
	};
	env.count = sizeof(envItems) / sizeof(AuthorizationItem);
	env.items = envItems;
    
	flags = kAuthorizationFlagDefaults| kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize;
	
	authorization = [SFAuthorization authorization];
    
	if (![authorization obtainWithRights:&rights flags:flags environment:&env authorizedRights:NULL error:outError])
	{
		return nil;
	}
	
	password = nil;
    
	status = AuthorizationCopyInfo([authorization authorizationRef], kAuthorizationEnvironmentPassword, &info);
	
	if (status == noErr) {
		if (info->count > 0 && info->items[0].valueLength > 0)
			password = [NSString stringWithUTF8String:info->items[0].value];
	}
	else {
		if (outError) {
			NSDictionary *info;
			info = [NSDictionary dictionaryWithObject:NSLocalizedString(@"Authorization did not return a password.", nil)
											   forKey:NSLocalizedDescriptionKey];
			*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:info];
		}
	}
	
	AuthorizationFreeItemSet(info);
    
	return password;
}

@end
