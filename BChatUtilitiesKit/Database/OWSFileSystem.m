// stringlint:disable

#import "OWSFileSystem.h"
#import "AppContext.h"

NS_ASSUME_NONNULL_BEGIN

@implementation OWSFileSystem

+ (BOOL)protectRecursiveContentsAtPath:(NSString *)path
{
    BOOL isDirectory;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory]) {
        return NO;
    }

    if (!isDirectory) {
        return [self protectFileOrFolderAtPath:path];
    }
    NSString *dirPath = path;

    BOOL success = YES;
    NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:dirPath];

    for (NSString *relativePath in directoryEnumerator) {
        NSString *filePath = [dirPath stringByAppendingPathComponent:relativePath];

        success = success && [self protectFileOrFolderAtPath:filePath];
    }

    return success;
}

+ (BOOL)protectFileOrFolderAtPath:(NSString *)path
{
    return [self protectFileOrFolderAtPath:path fileProtectionType:NSFileProtectionCompleteUntilFirstUserAuthentication];
}

+ (BOOL)protectFileOrFolderAtPath:(NSString *)path fileProtectionType:(NSFileProtectionType)fileProtectionType
{
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) {
        return NO;
    }

    NSError *error;
    NSDictionary *fileProtection = @{ NSFileProtectionKey : fileProtectionType };
    [[NSFileManager defaultManager] setAttributes:fileProtection ofItemAtPath:path error:&error];

    NSDictionary *resourcesAttrs = @{ NSURLIsExcludedFromBackupKey : @YES };

    NSURL *ressourceURL = [NSURL fileURLWithPath:path];
    BOOL success = [ressourceURL setResourceValues:resourcesAttrs error:&error];

    if (error || !success) {
        return NO;
    }
    return YES;
}

+ (NSString *)appLibraryDirectoryPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentDirectoryURL =
        [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    return [documentDirectoryURL path];
}

+ (NSString *)appDocumentDirectoryPath
{
    return CurrentAppContext().appDocumentDirectoryPath;
}

+ (NSString *)appSharedDataDirectoryPath
{
    return CurrentAppContext().appSharedDataDirectoryPath;
}

+ (NSString *)cachesDirectoryPath
{
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return paths[0];
}

+ (nullable NSError *)renameFilePathUsingRandomExtension:(NSString *)oldFilePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:oldFilePath]) {
        return nil;
    }

    NSString *newFilePath =
        [[oldFilePath stringByAppendingString:@"."] stringByAppendingString:[NSUUID UUID].UUIDString];


    NSError *_Nullable error;
    BOOL success = [fileManager moveItemAtPath:oldFilePath toPath:newFilePath error:&error];
    if (!success || error) {
        return error;
    }
    return nil;
}

+ (nullable NSError *)moveAppFilePath:(NSString *)oldFilePath sharedDataFilePath:(NSString *)newFilePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:oldFilePath]) {
        return nil;
    }

    if ([fileManager fileExistsAtPath:newFilePath]) {
        // If a file/directory already exists at the destination,
        // try to move it "aside" by renaming it with an extension.
        NSError *_Nullable error = [self renameFilePathUsingRandomExtension:newFilePath];
        if (error) {
            return error;
        }
    }

    if ([fileManager fileExistsAtPath:newFilePath]) {
        return [NSError errorWithDomain:@"OWSSignalServiceKitErrorDomain"
                                   code:777412
                               userInfo:@{ NSLocalizedDescriptionKey : @"Can't move file; destination already exists." }];
    }
        
    NSError *_Nullable error;
    BOOL success = [fileManager moveItemAtPath:oldFilePath toPath:newFilePath error:&error];
    if (!success || error) {
        return error;
    }

    // Ensure all files moved have the proper data protection class.
    // On large directories this can take a while, so we dispatch async
    // since we're in the launch path.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self protectRecursiveContentsAtPath:newFilePath];
    });

    return nil;
}

+ (BOOL)ensureDirectoryExists:(NSString *)dirPath
{
    return [self ensureDirectoryExists:dirPath fileProtectionType:NSFileProtectionCompleteUntilFirstUserAuthentication];
}

+ (BOOL)ensureDirectoryExists:(NSString *)dirPath fileProtectionType:(NSFileProtectionType)fileProtectionType
{
    BOOL isDirectory;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:dirPath isDirectory:&isDirectory];
    if (exists) {
        return [self protectFileOrFolderAtPath:dirPath fileProtectionType:fileProtectionType];
    } else {

        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:dirPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error) {
            return NO;
        }
        return [self protectFileOrFolderAtPath:dirPath fileProtectionType:fileProtectionType];
    }
}

+ (BOOL)ensureFileExists:(NSString *)filePath
{
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
    if (exists) {
        return [self protectFileOrFolderAtPath:filePath];
    } else {
        BOOL success = [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        if (!success) {
            return NO;
        }
        return [self protectFileOrFolderAtPath:filePath];
    }
}

+ (BOOL)deleteFile:(NSString *)filePath
{
    NSError *error;
    BOOL success = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
    if (!success || error) {
        return NO;
    }
    return YES;
}

+ (BOOL)deleteFileIfExists:(NSString *)filePath
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        return YES;
    }
    return [self deleteFile:filePath];
}

+ (NSArray<NSString *> *_Nullable)allFilesInDirectoryRecursive:(NSString *)dirPath error:(NSError **)error
{
    *error = nil;

    NSArray<NSString *> *filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirPath error:error];
    if (*error) {
        return nil;
    }

    NSMutableArray<NSString *> *filePaths = [NSMutableArray new];

    for (NSString *filename in filenames) {
        NSString *filePath = [dirPath stringByAppendingPathComponent:filename];

        BOOL isDirectory;
        [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory];
        if (isDirectory) {
            [filePaths addObjectsFromArray:[self allFilesInDirectoryRecursive:filePath error:error]];
            if (*error) {
                return nil;
            }
        } else {
            [filePaths addObject:filePath];
        }
    }

    return filePaths;
}

+ (NSString *)temporaryFilePath
{
    return [self temporaryFilePathWithFileExtension:nil];
}

+ (NSString *)temporaryFilePathWithFileExtension:(NSString *_Nullable)fileExtension
{
    NSString *temporaryDirectory = OWSTemporaryDirectory();
    NSString *tempFileName = NSUUID.UUID.UUIDString;
    if (fileExtension.length > 0) {
        tempFileName = [[tempFileName stringByAppendingString:@"."] stringByAppendingString:fileExtension];
    }
    NSString *tempFilePath = [temporaryDirectory stringByAppendingPathComponent:tempFileName];

    return tempFilePath;
}

+ (nullable NSString *)writeDataToTemporaryFile:(NSData *)data fileExtension:(NSString *_Nullable)fileExtension
{
    NSString *tempFilePath = [self temporaryFilePathWithFileExtension:fileExtension];
    NSError *error;
    BOOL success = [data writeToFile:tempFilePath options:NSDataWritingAtomic error:&error];
    if (!success || error) {
        return nil;
    }

    [self protectFileOrFolderAtPath:tempFilePath];

    return tempFilePath;
}

+ (nullable NSNumber *)fileSizeOfPath:(NSString *)filePath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *_Nullable error;
    unsigned long long fileSize =
        [[fileManager attributesOfItemAtPath:filePath error:&error][NSFileSize] unsignedLongLongValue];
    if (error) {
        return nil;
    } else {
        return @(fileSize);
    }
}

@end

#pragma mark -

NSString *OWSTemporaryDirectory(void)
{
    static NSString *dirPath;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *dirName = [NSString stringWithFormat:@"ows_temp_%@", NSUUID.UUID.UUIDString];
        dirPath = [NSTemporaryDirectory() stringByAppendingPathComponent:dirName];
        [OWSFileSystem ensureDirectoryExists:dirPath fileProtectionType:NSFileProtectionComplete];
    });
    return dirPath;
}

NSString *OWSTemporaryDirectoryAccessibleAfterFirstAuth(void)
{
    NSString *dirPath = NSTemporaryDirectory();
    [OWSFileSystem ensureDirectoryExists:dirPath
                      fileProtectionType:NSFileProtectionCompleteUntilFirstUserAuthentication];
    return dirPath;
}

void ClearOldTemporaryDirectoriesSync(void)
{
    // Ignore the "current" temp directory.
    NSString *currentTempDirName = OWSTemporaryDirectory().lastPathComponent;

    NSDate *thresholdDate = CurrentAppContext().appLaunchTime;
    NSString *dirPath = NSTemporaryDirectory();
    NSError *error;
    NSArray<NSString *> *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirPath error:&error];
    if (error) {
        return;
    }
    for (NSString *fileName in fileNames) {
        if (!CurrentAppContext().isAppForegroundAndActive) {
            // Abort if app not active.
            return;
        }
        if ([fileName isEqualToString:currentTempDirName]) {
            continue;
        }

        NSString *filePath = [dirPath stringByAppendingPathComponent:fileName];

        // Delete files with either:
        //
        // a) "ows_temp" name prefix.
        // b) modified time before app launch time.
        if (![fileName hasPrefix:@"ows_temp"]) {
            NSError *e;
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&e];
            if (!attributes || e) {
                // This is fine; the file may have been deleted since we found it.
                continue;
            }
            // Don't delete files which were created in the last N minutes.
            NSDate *creationDate = attributes.fileModificationDate;
            if (creationDate.timeIntervalSince1970 > thresholdDate.timeIntervalSince1970) {
                continue;
            }
        }

        if (![OWSFileSystem deleteFile:filePath]) {
            // This can happen if the app launches before the phone is unlocked.
            // Clean up will occur when app becomes active.
        }
    }
}

// NOTE: We need to call this method on launch _and_ every time the app becomes active,
// since file protection may prevent it from succeeding in the background.
void ClearOldTemporaryDirectories(void)
{
    // We use the lowest priority queue for this, and wait N seconds
    // to avoid interfering with app startup.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.f * NSEC_PER_SEC)),
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
        ^{
            ClearOldTemporaryDirectoriesSync();
        });
}

NS_ASSUME_NONNULL_END
