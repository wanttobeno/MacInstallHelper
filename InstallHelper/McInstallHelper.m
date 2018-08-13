//
//  McInstallHelper.m
//  InstallHelper
//
//  Created by TanHao on 12-9-6.
//  Copyright (c) 2012年 http://www.tanhao.me. All rights reserved.
//

#import "McInstallHelper.h"
#import "STPrivilegedTask.h"
#import "McAttachDiskImage.h"

enum
{
    McFileTypeUnknown,
    McFileTypeFolder,
    McFileTypeApp,
    McFileTypeZip,
    McFileTypeDmg,
    McFileTypePkg,
    McFileTypeWidgets,
    McFileTypePreferencePanes
};
typedef NSInteger McFileType;

/*
//判断文件类型,该方法对于刚建立的文件,无法获取文件类型
static McFileType fileType(NSString *filePath)
{
    MDItemRef item =  MDItemCreate(kCFAllocatorDefault, (__bridge CFStringRef)filePath);
    if (!item)
    {
        return McFileTypeUnknown;
    }
    NSString *fileType = (__bridge_transfer NSString*)MDItemCopyAttribute(item, kMDItemContentType);
    CFRelease(item);
    if (!fileType)
    {
        return McFileTypeUnknown;
    }
    if ([fileType isEqualToString:@"public.folder"])
    {
        return McFileTypeFolder;
    }
    if ([fileType isEqualToString:@"public.zip-archive"]
        ||[fileType isEqualToString:@"public.tar-archive"]
        ||[fileType isEqualToString:@"org.gnu.gnu-zip-archive"]
        ||[fileType isEqualToString:@"org.gnu.gnu-zip-tar-archive"])
    {
        //public.zip-archive(.zip)
        //public.tar-archive(.tar)
        //org.gnu.gnu-zip-archive(.tar.gz)
        //org.gnu.gnu-zip-tar-archive(.tgz)
        return McFileTypeZip;
    }
    if ([fileType isEqualToString:@"com.apple.application-bundle"])
    {
        return McFileTypeApp;
    }
    if ([fileType isEqualToString:@"com.apple.disk-image-udif"])
    {
        return McFileTypeDmg;
    }
    if ([fileType hasPrefix:@"com.apple.installer"]||[filePath hasSuffix:@".pkg"])
    {
        //com.apple.installer-package(pkg)
        //com.apple.installer-package-archive(mpkg)
        //com.apple.installer-meta-package(mpkg/pkg)
        return McFileTypePkg;
    }
    return McFileTypeUnknown;
}
 */

@implementation McInstallHelper

- (McFileType)fileType:(NSString *)filePath
{
    BOOL isDirectory = NO;
    BOOL isExists = [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
    if (!isExists)
    {
        return McFileTypeUnknown;
    }
    NSString *fileExtension = [[filePath pathExtension] lowercaseString];
    if ([fileExtension isEqualToString:@"zip"]
        ||[fileExtension isEqualToString:@"tar"]
        ||[fileExtension isEqualToString:@"tar.gz"]
        ||[fileExtension isEqualToString:@"tgz"]
        ||[fileExtension isEqualToString:@"tbz"]
        ||[fileExtension isEqualToString:@"xar"])
    {
        return McFileTypeZip;
    }
    if ([fileExtension isEqualToString:@"app"])
    {
        return McFileTypeApp;
    }
    if ([fileExtension isEqualToString:@"dmg"])
    {
        return McFileTypeDmg;
    }
    if ([fileExtension isEqualToString:@"pkg"]
        ||[fileExtension isEqualToString:@"mpkg"])
    {
        return McFileTypePkg;
    }
    if ([fileExtension isEqualToString:@"wdgt"])
    {
        return McFileTypeWidgets;
    }
    if ([fileExtension isEqualToString:@"prefpane"])
    {
        return McFileTypePreferencePanes;
    }
    if (isDirectory)
    {
        BOOL isPackage = [[NSWorkspace sharedWorkspace] isFilePackageAtPath:filePath];
        if (!isPackage)
        {
            return McFileTypeFolder;
        }
    }
    return McFileTypeUnknown;
}

- (void)killApplicationWithPath:(NSString *)filePath
{
    NSDictionary *info = nil;
    NSString *infoPath = [filePath stringByAppendingPathComponent:@"/Contents/Info.plist"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:infoPath])
    {
        info = [[NSDictionary alloc] initWithContentsOfFile:infoPath];
    }else
    {
        NSBundle *bundle = [NSBundle bundleWithPath:filePath];
        if (bundle)
        {
            info = [bundle infoDictionary];
        }
    }
    
    if (!info)
    {
        return;
    }
    
    NSString *bundleID = [info objectForKey:(__bridge NSString*)kCFBundleIdentifierKey];
    if (bundleID)
    {
        NSArray *applications = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleID];
        for (NSRunningApplication *aApplication in applications)
        {
            [aApplication forceTerminate];
        }
    }
}

- (BOOL)removeFile:(NSString *)filePath error:(NSError **)error
{    
    BOOL isDeletable = [[NSFileManager defaultManager] isDeletableFileAtPath:filePath];
    if (isDeletable)
    {
        BOOL result = [[NSFileManager defaultManager] removeItemAtPath:filePath error:error];
        if (result)
        {
            return result;
        }
    }
    
    STPrivilegedTask *uncompressTask = [[STPrivilegedTask alloc] init];
    @try
    {
        [uncompressTask setLaunchPath:@"/bin/rm"];
        [uncompressTask setArguments:[NSArray arrayWithObjects:@"-r",@"-d",@"-f",filePath,nil]];
        int state = [uncompressTask launch];
        if (state != 0)
        {
            return NO;
        }
    }
    @catch (NSException *exception)
    {
        return NO;
    }
    [uncompressTask waitUntilExit];
    if ([uncompressTask terminationStatus] != 0)
    {
        return NO;
    }
    return YES;
}

- (BOOL)copyAtPath:(NSString *)atPath toPath:(NSString *)toPath error:(NSError **)error
{
    BOOL isWritable = [[NSFileManager defaultManager] isWritableFileAtPath:[toPath stringByDeletingLastPathComponent]];
    if (isWritable)
    {
        BOOL result = [[NSFileManager defaultManager] copyItemAtPath:atPath toPath:toPath error:error];
        if (result)
        {
            return result;
        }
    }
    
    STPrivilegedTask *uncompressTask = [[STPrivilegedTask alloc] init];
    @try
    {
        [uncompressTask setLaunchPath:@"/bin/cp"];
        [uncompressTask setArguments:[NSArray arrayWithObjects:@"-r",@"-d",@"-f",atPath,toPath,nil]];
        int state = [uncompressTask launch];
        if (state != 0)
        {
            return NO;
        }
    }
    @catch (NSException *exception)
    {
        return NO;
    }
    [uncompressTask waitUntilExit];
    if ([uncompressTask terminationStatus] != 0)
    {
        return NO;
    }
    return YES;
}

- (BOOL)installAppFile:(NSString *)filePath
{    
    NSString *fileName = [filePath lastPathComponent];
    NSString *desPath = [@"/Applications" stringByAppendingPathComponent:fileName];
    NSError *error = NULL;
    if ([[NSFileManager defaultManager] fileExistsAtPath:desPath])
    {
        [self killApplicationWithPath:desPath];
        if ([filePath isEqualToString:desPath])
        {
            return YES;
        }
        BOOL success = [self removeFile:desPath error:&error];
        if (!success)
        {
            return NO;
        }
    }
    return [self copyAtPath:filePath toPath:desPath error:&error];
}

- (BOOL)installWidgets:(NSString *)filePath
{
    NSString *fileName = [filePath lastPathComponent];
    NSString *desPath = [@"/Library/Widgets" stringByAppendingPathComponent:fileName];
    NSError *error = NULL;
    if ([[NSFileManager defaultManager] fileExistsAtPath:desPath])
    {
        if ([filePath isEqualToString:desPath])
        {
            return YES;
        }
        BOOL success = [self removeFile:desPath error:&error];
        if (!success)
        {
            return NO;
        }
    }
    return [self copyAtPath:filePath toPath:desPath error:&error];
}

- (BOOL)installPreferencePanes:(NSString *)filePath
{
    NSString *fileName = [filePath lastPathComponent];
    NSString *desPath = [@"/Library/PreferencePanes" stringByAppendingPathComponent:fileName];
    NSError *error = NULL;
    if ([[NSFileManager defaultManager] fileExistsAtPath:desPath])
    {
        if ([filePath isEqualToString:desPath])
        {
            return YES;
        }
        BOOL success = [self removeFile:desPath error:&error];
        if (!success)
        {
            return NO;
        }
    }
    return [self copyAtPath:filePath toPath:desPath error:&error];
}

- (NSString *)uncompressZipFile:(NSString *)filePath
{
    NSString *desPath = [filePath stringByDeletingPathExtension];
    do {
        desPath = [desPath stringByAppendingFormat:@"_"];
    } while ([[NSFileManager defaultManager] fileExistsAtPath:desPath]);
    
    NSTask *uncompressTask = [[NSTask alloc] init];
    @try
    {
        NSString *fileExtension = [[filePath pathExtension] lowercaseString];
        if ([fileExtension isEqualToString:@"zip"])
        {
            [uncompressTask setLaunchPath:@"/usr/bin/ditto"];
            [uncompressTask setArguments:[NSArray arrayWithObjects:@"-x",@"-k",filePath,desPath, nil]];
            [uncompressTask launch];
        }else
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:desPath withIntermediateDirectories:YES attributes:nil error:NULL];
             [uncompressTask setLaunchPath:@"/usr/bin/bsdtar"];
            [uncompressTask setArguments:[NSArray arrayWithObjects:@"-x",@"-z",@"-f",filePath,@"-C",desPath,nil]];
            [uncompressTask launch];
        }
    }
    @catch (NSException *exception)
    {
        [[NSFileManager defaultManager] removeItemAtPath:desPath error:NULL];
        return nil;
    }
    [uncompressTask waitUntilExit];
    if ([uncompressTask terminationStatus] == 0)
    {
        return desPath;
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:desPath error:NULL];
    return nil;
}

- (NSString *)mountDmgFile:(NSString *)filePath
{
    NSError *error = NULL;
    NSString *desPath = [McAttachDiskImage mountDiskImageAtPath:filePath password:NULL error:&error];
    return desPath;
}

- (BOOL)installPkgFile:(NSString *)filePath
{
    STPrivilegedTask *uncompressTask = [[STPrivilegedTask alloc] init];
    @try
    {
        [uncompressTask setLaunchPath:@"/usr/sbin/installer"];
        [uncompressTask setArguments:[NSArray arrayWithObjects:@"-pkg",filePath,@"-target",@"LocalSystem", nil]];
        int state = [uncompressTask launch];
        if (state != 0)
        {
            return NO;
        }
    }
    @catch (NSException *exception)
    {
        return NO;
    }
    [uncompressTask waitUntilExit];
    if ([uncompressTask terminationStatus] == 0)
    {
        return YES;
    }
    return NO;
}

- (BOOL)installWithPath:(NSString *)filePath
{
    McFileType type = [self fileType:filePath];
    if (type == McFileTypeUnknown)
    {
        return NO;
    }
    if (type == McFileTypeApp)
    {
        return [self installAppFile:filePath];
    }
    if (type == McFileTypePkg)
    {
        return [self installPkgFile:filePath];
    }
    if (type == McFileTypeZip)
    {
        NSString *resultPath = [self uncompressZipFile:filePath];
        BOOL resultFlag = [self installWithPath:resultPath];
        [[NSFileManager defaultManager] removeItemAtPath:resultPath error:NULL];
        return resultFlag;
    }
    if (type == McFileTypeDmg)
    {
        NSString *resultPath = [self mountDmgFile:filePath];
        if (!resultPath)
        {
            return NO;
        }
        BOOL resultFlag = [self installWithPath:resultPath];
        [McAttachDiskImage ejectAtPath:resultPath];
        return resultFlag;
    }
    if (type == McFileTypeWidgets)
    {
        return [self installWidgets:filePath];
    }
    if (type == McFileTypePreferencePanes)
    {
        return [self installPreferencePanes:filePath];
    }
    if (type == McFileTypeFolder)
    {
        BOOL installFlag = YES;
        NSArray *subPaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:filePath error:NULL];
        for (NSString *path in subPaths)
        {
            if ([[path lastPathComponent] hasPrefix:@"."]
                ||[[path lastPathComponent] hasPrefix:@"__MACOSX"])
            {
                continue;
            }
            NSString *fullPath = [filePath stringByAppendingPathComponent:path];
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:NULL];
            NSString *attType = [attributes objectForKey:NSFileType];
            if ([attType isEqualToString:NSFileTypeSymbolicLink])
            {
                continue;
            }
            
            if ([self fileType:fullPath] == McFileTypeUnknown)
            {
                continue;
            }
            BOOL currentFlag = [self installWithPath:fullPath];
            installFlag &= currentFlag;
        }
        return installFlag;
    }
    return NO;
}

@end
