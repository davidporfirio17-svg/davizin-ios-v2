#import "DavizinMCM.h"
#import "mcm_bridge.h"
#import <Foundation/Foundation.h>

static inline void DavizinMCMLog(NSString *msg) {
    NSLog(@"[DavizinMCM] %@", msg);
}

NSString *DavizinGetContainerPath(NSString *bundleID, NSString **outErr) {
    if (!bundleID || bundleID.length == 0) {
        if (outErr) *outErr = @"bundleID es nil o vacío";
        return nil;
    }

    // Try MCMActivateContainerPath first - grants write access via file descriptor
    // This is what External uses for actual file operations
    NSString *path = MCMActivateContainerPath(2, bundleID, NO, outErr);
    if (path) {
        DavizinMCMLog([NSString stringWithFormat:@"Container ACTIVADO para %@: %@", bundleID, path]);
        return path;
    }

    // Fallback: get path without activation (read-only)
    path = MCMContainerPathForIdentifier(2, bundleID, NO, outErr);
    if (path) {
        DavizinMCMLog([NSString stringWithFormat:@"Container encontrado (read-only) para %@: %@", bundleID, path]);
        return path;
    }

    if (outErr) {
        DavizinMCMLog([NSString stringWithFormat:@"No encontrado %@ - %@", bundleID, *outErr ?: @"unknown"]);
    }
    return nil;
}

NSString *DavizinPrepareInjectionQuery(NSString *bundleID, NSString **outErr) {
    // Stub for backward compatibility
    return nil;
}

NSString *DavizinMCMLastDiagnostic(void) {
    return @"Using External's mcm_bridge implementation";
}
