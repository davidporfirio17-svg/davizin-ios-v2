#import "DavizinMCM.h"
#import "bad_query.h"
#import <Foundation/Foundation.h>
#import <sys/stat.h>

static NSString *gDavizinMCMLastDiagnostic;
static int64_t gLastContainerHandle = -1;

NSString *DavizinMCMLastDiagnostic(void) {
    return gDavizinMCMLastDiagnostic;
}

static void DavizinMCMLog(NSString *message) {
    gDavizinMCMLastDiagnostic = message;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray<NSString *> *existing = [defaults stringArrayForKey:@"nyxel.activity.log"] ?: @[];
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"HH:mm";
    NSString *entry = [NSString stringWithFormat:@"%@  %@", [formatter stringFromDate:[NSDate date]], message];
    NSMutableArray<NSString *> *values = [NSMutableArray arrayWithObject:entry];
    [values addObjectsFromArray:existing];
    if (values.count > 6) [values removeObjectsInRange:NSMakeRange(6, values.count - 6)];
    [defaults setObject:values forKey:@"nyxel.activity.log"];
}

static NSString *findContainerByBundleID(NSString *rootPath, NSString *bundleID) {
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:rootPath error:nil];
    for (NSString *uuid in contents) {
        if ([NSUUID.alloc initWithUUIDString:uuid] == nil) continue;
        NSString *containerPath = [rootPath stringByAppendingPathComponent:uuid];
        NSString *metadataPath = [containerPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];

        NSData *data = [NSData dataWithContentsOfFile:metadataPath];
        if (!data) continue;

        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:nil];
        if (![plist isKindOfClass:[NSDictionary class]]) continue;

        NSString *containerBundleID = plist[@"MCMMetadataIdentifier"];
        if ([containerBundleID isEqualToString:bundleID]) {
            return containerPath;
        }
    }
    return nil;
}

NSString *DavizinGetContainerPath(NSString *bundleID, NSString **outErr) {
    // Release previous handle if any
    if (gLastContainerHandle >= 0) {
        bad_query_release(gLastContainerHandle);
        gLastContainerHandle = -1;
    }

    NSString *appDataRoot = @"/var/mobile/Containers/Data/Application";

    // Step 1: Grant access to the root for enumeration
    char rootPathC[1024];
    strlcpy(rootPathC, appDataRoot.UTF8String, sizeof(rootPathC));
    int64_t rootHandle = bad_query(rootPathC, true, NULL, false);

    // Step 2: Enumerate and find the container
    NSString *foundPath = findContainerByBundleID(appDataRoot, bundleID);

    // Release the root handle after enumeration
    if (rootHandle >= 0) {
        bad_query_release(rootHandle);
    }

    if (!foundPath) {
        if (outErr) *outErr = [NSString stringWithFormat:@"No encontrado '%@' root_handle=%lld", bundleID, rootHandle];
        DavizinMCMLog([NSString stringWithFormat:@"MCM %@: no encontrado root=%lld", bundleID, rootHandle]);
        return nil;
    }

    // Step 3: Grant access to the specific container (keep handle alive)
    char containerC[1024];
    strlcpy(containerC, foundPath.UTF8String, sizeof(containerC));
    gLastContainerHandle = bad_query(containerC, true, NULL, false);

    DavizinMCMLog([NSString stringWithFormat:@"MCM %@: path=%@ handle=%lld",
                   bundleID, foundPath.lastPathComponent, gLastContainerHandle]);

    if (gLastContainerHandle < 0) {
        if (outErr) *outErr = [NSString stringWithFormat:@"bad_query failed handle=%lld", gLastContainerHandle];
    }

    return foundPath;
}
