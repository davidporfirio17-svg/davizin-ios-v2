#ifndef NYXEL_IDEVICE_FFI_H
#define NYXEL_IDEVICE_FFI_H

#include <stddef.h>
#include <sys/socket.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct IdeviceFfiError IdeviceFfiError;
typedef struct RpPairingFileHandle RpPairingFileHandle;
typedef struct AdapterHandle AdapterHandle;
typedef struct RsdHandshakeHandle RsdHandshakeHandle;
typedef socklen_t idevice_socklen_t;
typedef struct sockaddr idevice_sockaddr;

typedef const char *(*nyxel_pin_callback)(void *context);

IdeviceFfiError *rp_pairing_file_generate(const char *hostname,
                                           RpPairingFileHandle **out);
IdeviceFfiError *rp_pairing_file_to_bytes(RpPairingFileHandle *handle,
                                          unsigned char **out_data,
                                          size_t *out_len);
void rp_pairing_file_free(RpPairingFileHandle *handle);
void idevice_data_free(unsigned char *data, size_t len);

IdeviceFfiError *tunnel_create_rppairing(
    const idevice_sockaddr *addr,
    idevice_socklen_t addr_len,
    const char *hostname,
    RpPairingFileHandle *pairing_file,
    const char *(*pin_callback)(void *context),
    void *pin_context,
    AdapterHandle **out_adapter,
    RsdHandshakeHandle **out_handshake);

void adapter_free(AdapterHandle *handle);
void rsd_handshake_free(RsdHandshakeHandle *handle);

#ifdef __cplusplus
}
#endif

#endif
