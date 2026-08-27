#import "DavizinMCM.h"
#import <dlfcn.h>
#import <stdlib.h>
#import <xpc/xpc.h>
#import <Security/Security.h>
#import <fcntl.h>
#import <unistd.h>

// ── Sandbox extension consume (libsandbox private API) ──────────
// Esta es la clave para obtener acceso de escritura real
extern int64_t sandbox_extension_consume(const char *token);

// ── Container Manager function types ────────────────────────────
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
} CMAPI;

static CMAPI *getCMAPI(void) {
    static CMAPI api;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = dlopen("/usr/lib/system/libsystem_containermanager.dylib",
                         RTLD_NOW | RTLD_LOCAL);
        if (!h) h = RTLD_DEFAULT;
#define L(f,s) api.f = (__typeof(api.f))dlsym(h,s)
        L(queryCreate,   "container_query_create");
        L(querySetClass, "container_query_set_class");
        L(querySetIds,   "container_query_set_identifiers");
        L(querySetFlags, "container_query_operation_set_flags");
        L(queryGetSingle,"container_query_get_single_result");
        L(queryGetErr,   "container_query_get_last_error");
        L(queryFree,     "container_query_free");
        L(objGetPath,    "container_object_get_path");
        L(objCopyToken,  "container_copy_sandbox_token");
        L(objFree,       "container_object_free");
        L(errPosix,      "container_error_get_posix_errno");
        L(errMsg,        "container_error_get_message");
#undef L
    });
    return &api;
}

// ── Signing identifier check ─────────────────────────────────────
typedef CFTypeRef SecTaskRef;
extern SecTaskRef SecTaskCreateFromSelf(CFAllocatorRef allocator);
extern CFStringRef SecTaskCopySigningIdentifier(SecTaskRef task, CFErrorRef *error);

static NSString *signingID(void) {
    static NSString *result;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
        if (task) {
            CFErrorRef err = NULL;
            CFStringRef v = SecTaskCopySigningIdentifier(task, &err);
            if (v) { result = [(__bridge NSString *)v copy]; CFRelease(v); }
            if (err) CFRelease(err);
            CFRelease(task);
        }
    });
    return result;
}

// ── Main function ────────────────────────────────────────────────
NSString *DavizinGetContainerPath(NSString *bundleID, NSString **outErr) {
    static NSString *kRequired = @"com.apple.mobile.MobileHouseArrest";
    static const uint64_t kClass = 2;       // App data container
    static const uint64_t kFlags = 0x900000000ULL;

    // 1. Verificar signing identifier
    NSString *sid = signingID();
    if (![sid isEqualToString:kRequired]) {
        if (outErr) *outErr = [NSString stringWithFormat:@"Signing ID: '%@'", sid];
        return nil;
    }

    CMAPI *api = getCMAPI();
    if (!api->queryCreate || !api->queryGetSingle || !api->objGetPath) {
        if (outErr) *outErr = @"libsystem_containermanager no disponible";
        return nil;
    }

    // 2. Crear query
    void *query = api->queryCreate();
    if (!query) {
        if (outErr) *outErr = @"container_query_create → NULL";
        return nil;
    }

    api->querySetClass(query, kClass);
    xpc_object_t xpcID = xpc_string_create(bundleID.UTF8String);
    api->querySetIds(query, xpcID);
    api->querySetFlags(query, kFlags);

    // 3. Obtener objeto container
    void *obj = api->queryGetSingle(query);
    if (!obj) {
        int posix = 0;
        const char *msg = NULL;
        void *qErr = api->queryGetErr ? api->queryGetErr(query) : NULL;
        if (qErr) {
            if (api->errPosix) posix = api->errPosix(qErr);
            if (api->errMsg)   msg   = api->errMsg(qErr);
        }
        if (outErr) *outErr = [NSString stringWithFormat:
            @"Container no encontrado '%@' (posix=%d %s)",
            bundleID, posix, msg ?: ""];
        api->queryFree(query);
        return nil;
    }

    // 4. Obtener path
    const char *raw = api->objGetPath(obj);
    NSString *path = raw ? [NSString stringWithUTF8String:raw] : nil;

    if (!path || !path.isAbsolutePath) {
        if (outErr) *outErr = @"Path inválido del container";
        api->queryFree(query);
        return nil;
    }

    // Normalizar /var → /private/var
    if ([path isEqualToString:@"/var"] || [path hasPrefix:@"/var/"])
        path = [@"/private" stringByAppendingString:path];

    // 5. Obtener sandbox token y consumirlo con sandbox_extension_consume
    // Esta es la clave para escribir archivos en el container
    if (api->objCopyToken) {
        char *token = api->objCopyToken(obj);
        if (token && token[0] != '\0') {
            // sandbox_extension_consume activa el permiso de lectura/escritura
            int64_t result = sandbox_extension_consume(token);
            if (result == -1) {
                // Si falla, intentar de todas formas
                NSLog(@"[DavizinMCM] sandbox_extension_consume falló, continuando...");
            }
        }
        if (token) free(token);
    }

    api->queryFree(query);
    return path;
}
