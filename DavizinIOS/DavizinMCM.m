#import "DavizinMCM.h"
#import <dlfcn.h>
#import <stdlib.h>
#import <xpc/xpc.h>
#import <Security/Security.h>
#import <fcntl.h>
#import <unistd.h>

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
        LOAD(querySetPart,       "container_query_operation_set_part");
        LOAD(queryGetSingle,     "container_query_get_single_result");
        LOAD(queryGetLastError,  "container_query_get_last_error");
        LOAD(queryFree,          "container_query_free");
        LOAD(objectGetPath,      "container_object_get_path");
        LOAD(objectCopy,         "container_object_copy");
        LOAD(objectCopyToken,    "container_copy_sandbox_token");
        LOAD(objectActivate,     "container_object_sandbox_extension_activate");
        LOAD(objectFree,         "container_object_free");
        LOAD(errorGetPOSIX,      "container_error_get_posix_errno");
        LOAD(errorGetMessage,    "container_error_get_message");
#undef LOAD
    });
    return &api;
}

typedef CFTypeRef SecTaskRef;
extern SecTaskRef SecTaskCreateFromSelf(CFAllocatorRef allocator);
extern CFStringRef SecTaskCopySigningIdentifier(SecTaskRef task, CFErrorRef *error);

static NSString *MCMSigningIdentifier(void) {
    static NSString *identifier;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
        if (task) {
            CFErrorRef err = NULL;
            CFStringRef value = SecTaskCopySigningIdentifier(task, &err);
            if (value) identifier = [(__bridge NSString *)value copy];
            if (value) CFRelease(value);
            if (err)   CFRelease(err);
            CFRelease(task);
        }
    });
    return identifier;
}

NSString *DavizinGetContainerPath(NSString *bundleID, NSString **outError) {
    static const NSString *kRequiredID = @"com.apple.mobile.MobileHouseArrest";
    // Flags de lectura/escritura para iOS 26
    static const uint64_t kFlagsRW = 0x8100000000ULL;
    static const uint64_t kFlagsRO = 0x900000000ULL;
    static const uint64_t kClass = 2;

    NSString *signingID = MCMSigningIdentifier();
    if (![signingID isEqualToString:(NSString *)kRequiredID]) {
        if (outError) *outError = [NSString stringWithFormat:
            @"Signing ID: '%@'", signingID];
        return nil;
    }

    MCMAPI *api = MCMGetAPI();
    if (!api->queryCreate || !api->queryGetSingle || !api->objectGetPath) {
        if (outError) *outError = @"containermanager no disponible";
        return nil;
    }

    // Intentar primero con flags de lectura/escritura
    NSString *path = nil;
    for (uint64_t flags in @[@(kFlagsRW), @(kFlagsRO)]) {
        void *query = api->queryCreate();
        if (!query) continue;

        api->querySetClass(query, kClass);
        xpc_object_t xpcID = xpc_string_create(bundleID.UTF8String);
        api->querySetIdentifiers(query, xpcID);
        api->querySetFlags(query, flags);
        if (api->querySetPart) api->querySetPart(query, 0);

        void *object = api->queryGetSingle(query);
        if (object) {
            const char *rawPath = api->objectGetPath(object);
            NSString *candidatePath = rawPath ? [NSString stringWithUTF8String:rawPath] : nil;

            if (candidatePath.length > 0 && candidatePath.isAbsolutePath) {
                if ([candidatePath isEqualToString:@"/var"] || [candidatePath hasPrefix:@"/var/"])
                    candidatePath = [@"/private" stringByAppendingString:candidatePath];

                // Activar sandbox extension
                void *copy = api->objectCopy ? api->objectCopy(object) : NULL;
                if (copy) {
                    char *token = api->objectCopyToken ? api->objectCopyToken(copy) : NULL;
                    if (token) {
                        api->objectActivate(copy, false);
                        free(token);
                    }
                    if (api->objectFree) api->objectFree(copy);
                }
                path = candidatePath;
                api->queryFree(query);
                break;
            }
        }
        api->queryFree(query);
    }

    if (!path) {
        if (outError) *outError = [NSString stringWithFormat:
            @"Container no encontrado para '%@'", bundleID];
        return nil;
    }

    return path;
}
