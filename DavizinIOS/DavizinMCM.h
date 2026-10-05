#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Obtiene el path del container de datos de una app por bundle ID.
/// Usa bad_query (path traversal) para escapar del sandbox.
NSString * _Nullable DavizinGetContainerPath(NSString *bundleID,
                                              NSString * _Nullable * _Nullable error);

/// Stub for backward compatibility
NSString * _Nullable DavizinPrepareInjectionQuery(NSString *bundleID,
                                                  NSString * _Nullable * _Nullable error);

/// Diagnóstico de la última llamada a DavizinGetContainerPath: si hubo
/// token de sandbox y qué devolvió sandbox_extension_consume.
NSString * _Nullable DavizinMCMLastDiagnostic(void);

NS_ASSUME_NONNULL_END
