#import "DavizinMCM.h"
#import "mcm_bridge.h"
#import "NixelIdeviceFFI.h"
#import "NixelAirLiftBridge.h"
#import "kexploit/kexploit_opa334.h"
#import "kexploit/sandbox_escape.h"
#import "kexploit/krw.h"
#import "kexploit/kutils.h"
#import "kexploit/vnode.h"
#import "kexploit/offsets.h"
#import "kexploit/bad_query.h"

// Kernel exploit functions (from kexploit_opa334.m)
extern int sandbox_access_is_active(void);
extern int kexploit_opa334(void);

// Swift wrappers for kernel exploit
static inline int IsSandboxAccessActive(void) {
    return sandbox_access_is_active();
}

static inline int KexploitOpa334Run(void) {
    return kexploit_opa334();
}

static inline int KexploitOpa334IsBroken(void) {
    // Si sandbox_access_is_active() retorna 0, sandbox escape no está activo
    return (sandbox_access_is_active() == 0) ? 1 : 0;
}
