#import "DavizinMCM.h"
#import <dlfcn.h>
#import <stdlib.h>
#import <fcntl.h>

// XPC sin importar el header — usamos void* directamente
typedef void *xpc_object_t;
typedef xpc_object_t (*xpc_string_create_t)(const char *);

typedef void *(*cm_query_create_t)(void);
typedef void  (*cm_query_set_u64_t)(void *, uint64_t);
typedef void  (*cm_query_set_xpc_t)(void *, xpc_object_t);
typedef void *(*cm_query_get_single_t)(void *);
typedef void *(*cm_query_get_err_t)(void *);
typedef void  (*cm_query_free_t)(void *);
typedef const char *(*cm_obj_get_path_t)(void *);
typedef char *(*cm_obj_copy_token_t)(void *);
typedef void  (*cm_obj_free_t)(void *);
typedef int   (*cm_err_posix_t)(void *);
typedef const char *(*cm_err_msg_t)(void *);
typedef int64_t (*sandbox_consume_t)(const char *);

typedef struct {
    cm_query_create_t   queryCreate;
    cm_query_set_u64_t  querySetClass;
    cm_query_set_xpc_t  querySetIds;
    cm_query_set_u64_t  querySetFlags;
    cm_query_get_single_t queryGetSingle;
    cm_query_get_err_t  queryGetErr;
    cm_query_free_t     queryFree;
    cm_obj_get_path_t   objGetPath;
    cm_obj_copy_token_t objCopyToken;
    cm_obj_free_t       objFree;
    cm_err_posix_t      errPosix;
    cm_err_msg_t        errMsg;
    xpc_string_create_t xpcStringCreate;
    sandbox_consume_t   sandboxConsume;
} CMAPI;

static CMAPI *getCMAPI(void) {
    static CMAPI api;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *cm = dlopen("/usr/lib/system/libsystem_containermanager.dylib", RTLD_NOW|RTLD_LOCAL);
        if (!cm) cm = RTLD_DEFAULT;
        void *xpc = dlopen("/usr/lib/system/libxpc.dylib", RTLD_NOW|RTLD_LOCAL);
        if (!xpc) xpc = RTLD_DEFAULT;
        void *sb = dlopen("/usr/lib/system/libsystem_sandbox.dylib", RTLD_NOW|RTLD_LOCAL);
        if (!sb) sb = RTLD_DEFAULT;
#define L(h,f,s) api.f = (__typeof(api.f))dlsym(h,s)
        L(cm, queryCreate,   "container_query_create");
        L(cm, querySetClass, "container_query_set_class");
        L(cm, querySetIds,   "container_query_set_identifiers");
        L(cm, querySetFlags, "container_query_operation_set_flags");
        L(cm, queryGetSingle,"container_query_get_single_result");
        L(cm, queryGetErr,   "container_query_get_last_error");
        L(cm, queryFree,     "container_query_free");
        L(cm, objGetPath,    "container_object_get_path");
        L(cm, objCopyToken,  "container_copy_sandbox_token");
        L(cm, objFree,       "container_object_free");
        L(cm, errPosix,      "container_error_get_posix_errno");
        L(cm, errMsg,        "container_error_get_message");
        L(xpc, xpcStringCreate, "xpc_string_create");
        L(sb,  sandboxConsume,  "sandbox_extension_consume");
#undef L
    });
    return &api;
}

// Signing identifier via dlsym
typedef void *SecTaskRef_t;
typedef SecTaskRef_t (*SecTaskCreateFromSelf_fn)(void *);
typedef void        *(*SecTaskCopySigningID_fn)(SecTaskRef_t, void **);

static NSString *getSigningID(void) {
    static NSString *result;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *sec = RTLD_DEFAULT;
        SecTaskCreateFromSelf_fn createFn = (SecTaskCreateFromSelf_fn)dlsym(sec, "SecTaskCreateFromSelf");
        SecTaskCopySigningID_fn  copyFn   = (SecTaskCopySigningID_fn)dlsym(sec, "SecTaskCopySigningIdentifier");
        if (createFn && copyFn) {
            SecTaskRef_t task = createFn(NULL);
            if (task) {
                void *err = NULL;
                void *val = copyFn(task, &err);
                if (val) {
                    result = [(__bridge NSString *)val copy];
                    CFRelease(val);
                }
                CFRelease(task);
            }
        }
    });
    return result;
}

NSString *DavizinGetContainerPath(NSString *bundleID, NSString **outErr) {
    static NSString *kRequired = @"com.apple.mobile.MobileHouseArrest";
    static const uint64_t kClass = 2;
    static const uint64_t kFlags = 0x900000000ULL;

    NSString *sid = getSigningID();
    if (![sid isEqualToString:kRequired]) {
        if (outErr) *outErr = [NSString stringWithFormat:@"Signing ID: '%@'", sid];
        return nil;
    }

    CMAPI *api = getCMAPI();
    if (!api->queryCreate || !api->queryGetSingle || !api->objGetPath) {
        if (outErr) *outErr = @"containermanager no disponible";
        return nil;
    }

    void *query = api->queryCreate();
    if (!query) {
        if (outErr) *outErr = @"query_create NULL";
        return nil;
    }

    api->querySetClass(query, kClass);

    xpc_object_t xpcID = NULL;
    if (api->xpcStringCreate)
        xpcID = api->xpcStringCreate(bundleID.UTF8String);
    if (xpcID) api->querySetIds(query, xpcID);

    api->querySetFlags(query, kFlags);

    void *obj = api->queryGetSingle(query);
    if (!obj) {
        int posix = 0; const char *msg = NULL;
        void *qe = api->queryGetErr ? api->queryGetErr(query) : NULL;
        if (qe && api->errPosix) posix = api->errPosix(qe);
        if (qe && api->errMsg)   msg   = api->errMsg(qe);
        if (outErr) *outErr = [NSString stringWithFormat:
            @"No encontrado '%@' posix=%d %s", bundleID, posix, msg ?: ""];
        api->queryFree(query);
        return nil;
    }

    const char *raw = api->objGetPath(obj);
    NSString *path = raw ? [NSString stringWithUTF8String:raw] : nil;
    if (!path || !path.isAbsolutePath) {
        if (outErr) *outErr = @"Path inválido";
        api->queryFree(query);
        return nil;
    }

    if ([path hasPrefix:@"/var/"])
        path = [@"/private" stringByAppendingString:path];

    // Activar sandbox extension
    if (api->objCopyToken) {
        char *token = api->objCopyToken(obj);
        if (token && token[0] && api->sandboxConsume)
            api->sandboxConsume(token);
        if (token) free(token);
    }

    api->queryFree(query);
    return path;
}
