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
    
    // Try to get container path for the app (class 2 = MCMApplicationDataContainer)
    NSString *path = MCMContainerPathForIdentifier(2, bundleID, NO, outErr);
    if (path) {
        DavizinMCMLog([NSString stringWithFormat:@"Container encontrado para %@: %@", bundleID, path]);
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
