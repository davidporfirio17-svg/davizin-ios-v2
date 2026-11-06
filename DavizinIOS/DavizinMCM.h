#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdbool.h>

NS_ASSUME_NONNULL_BEGIN

/// Obtiene un grant ACTIVO para acceso al container.
int64_t DavizinGrantContainerAccess(const char *containerPath);

/// Libera un grant previamente obtenido.
void DavizinReleaseContainerGrant(int64_t handle);

/// Obtiene el path del container de datos de una app por bundle ID.
NSString * _Nullable DavizinGetContainerPath(NSString *bundleID,
                                              NSString * _Nullable * _Nullable error);

/// Resultado del probe de escritura sin VPN para iOS 27+.
typedef struct {
    int method;          // 0=none, 1=mcm_activate, 2=mcm_raw_consume, 10+=bad_query variant
    int64_t handle;      // sandbox extension handle (keep alive while writing)
    bool writeOK;        // true si se verificó escritura real
    char detail[512];
} DavizinProbeResult;

/// Prueba múltiples métodos de sandbox escape para obtener escritura al container.
/// Retorna el primer método que logra escribir un canary file verificado.
DavizinProbeResult DavizinProbeContainerWriteAccess(NSString *containerPath, NSString *bundleID);

/// Libera el handle del probe.
void DavizinProbeRelease(DavizinProbeResult *result);

/// Stub for backward compatibility
NSString * _Nullable DavizinPrepareInjectionQuery(NSString *bundleID,
                                                  NSString * _Nullable * _Nullable error);

/// Diagnóstico.
NSString * _Nullable DavizinMCMLastDiagnostic(void);

NS_ASSUME_NONNULL_END
