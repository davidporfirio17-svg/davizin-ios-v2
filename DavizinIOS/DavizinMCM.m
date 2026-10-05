#import "DavizinMCM.h"
#import "mcm_bridge.h"
#import "kexploit/bad_query.h"
#import <Foundation/Foundation.h>

static inline void DavizinMCMLog(NSString *msg) {
    NSLog(@"[DavizinMCM] %@", msg);
}

/// Determina si necesitamos usar bad_query en esta versión de iOS
static inline BOOL shouldUseBadQuery(void) {
    NSOperatingSystemVersion osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    return osVersion.majorVersion >= 26;
}

/// Obtiene un grant activo para acceso al container.
/// Retorna un handle >= 0 si exitoso, < 0 si falla.
/// CRÍTICO: El grant se mantiene activo hasta que se llame bad_query_release(handle).
/// Este patrón es IGUAL al de External en iOS 26+.
int64_t DavizinGrantContainerAccess(const char *containerPath) {
    if (!shouldUseBadQuery()) {
        return -1;  // iOS < 26 no necesita grant
    }

    // Normalizar ruta (eliminar trailing slash si existe)
    NSString *cleanPath = [NSString stringWithUTF8String:containerPath];
    if ([cleanPath hasSuffix:@"/"]) {
        cleanPath = [cleanPath substringToIndex:cleanPath.length - 1];
    }

    // Convertir a C string
    const char *pathC = [cleanPath UTF8String];
    int64_t handle = bad_query((char *)pathC, true, NULL, false);

    if (handle >= 0) {
        DavizinMCMLog([NSString stringWithFormat:@"Grant obtenido para %@: handle=%lld", cleanPath, handle]);
    } else {
        DavizinMCMLog([NSString stringWithFormat:@"Grant FALLÓ para %@: handle=%lld", cleanPath, handle]);
    }

    return handle;
}

/// Libera un grant previamente obtenido.
void DavizinReleaseContainerGrant(int64_t handle) {
    if (handle >= 0) {
        bad_query_release(handle);
        DavizinMCMLog([NSString stringWithFormat:@"Grant liberado: handle=%lld", handle]);
    }
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
