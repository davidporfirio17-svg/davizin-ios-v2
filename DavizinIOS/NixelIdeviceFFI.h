#ifndef NYXEL_IDEVICE_FFI_H
#define NYXEL_IDEVICE_FFI_H

#include <stddef.h>
#include <sys/socket.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct IdeviceFfiError IdeviceFfiError;
typedef socklen_t idevice_socklen_t;
typedef struct sockaddr idevice_sockaddr;

IdeviceFfiError *rp_pairing_file_generate(const char *hostname,
                                           void **out);
IdeviceFfiError *rp_pairing_file_from_bytes(const unsigned char *data,
                                             size_t len,
                                             void **out);
IdeviceFfiError *rp_pairing_file_to_bytes(void *handle,
                                          unsigned char **out_data,
                                          size_t *out_len);
void rp_pairing_file_free(void *handle);
void idevice_data_free(unsigned char *data, size_t len);

IdeviceFfiError *tunnel_create_rppairing(
    const idevice_sockaddr *addr,
    idevice_socklen_t addr_len,
    const char *hostname,
    void *pairing_file,
    const char *(*pin_callback)(void *context),
    void *pin_context,
    void **out_adapter,
    void **out_handshake);

void adapter_free(void *handle);
void rsd_handshake_free(void *handle);

#ifdef __cplusplus
}
#endif

#endif
