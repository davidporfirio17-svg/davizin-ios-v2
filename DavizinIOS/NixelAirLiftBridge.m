#import "NixelAirLiftBridge.h"
#import "NixelIdeviceFFI.h"
#import <Foundation/Foundation.h>
#import <dns_sd.h>
#import <netdb.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <sys/socket.h>

struct NyxelResolveContext {
    struct sockaddr_storage address;
    socklen_t length;
    char host[256];
    uint16_t port;
    int done;
    int error;
};

static void nyxel_resolve_callback(DNSServiceRef sdRef, DNSServiceFlags flags, uint32_t interfaceIndex,
                                   DNSServiceErrorType errorCode, const char *fullname,
                                   const char *hosttarget, uint16_t port, uint16_t txtLen,
                                   const char *txtRecord, void *context) {
    (void)sdRef; (void)flags; (void)interfaceIndex; (void)fullname; (void)txtLen; (void)txtRecord;
    struct NyxelResolveContext *ctx = context;
    if (errorCode != kDNSServiceErr_NoError || !hosttarget) { ctx->error = 1; ctx->done = 1; return; }
    ctx->port = ntohs(port);
    snprintf(ctx->host, sizeof(ctx->host), "%s", hosttarget);
    struct addrinfo hints = {0};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    struct addrinfo *result = NULL;
    if (getaddrinfo(hosttarget, NULL, &hints, &result) != 0 || !result) { ctx->error = 2; ctx->done = 1; return; }
    memcpy(&ctx->address, result->ai_addr, result->ai_addrlen);
    ctx->length = (socklen_t)result->ai_addrlen;
    if (ctx->address.ss_family == AF_INET) ((struct sockaddr_in *)&ctx->address)->sin_port = htons(ctx->port);
    if (ctx->address.ss_family == AF_INET6) ((struct sockaddr_in6 *)&ctx->address)->sin6_port = htons(ctx->port);
    freeaddrinfo(result);
    ctx->done = 1;
}

static int nyxel_resolve(const char *service, const char *regtype, struct sockaddr_storage *address, socklen_t *length) {
    if (!service || !regtype || !address || !length) return -1;
    struct NyxelResolveContext ctx = {0};
    DNSServiceRef ref = NULL;
    DNSServiceErrorType e = DNSServiceResolve(&ref, 0, 0, service, regtype, "local.", nyxel_resolve_callback, &ctx);
    if (e != kDNSServiceErr_NoError || !ref) return -2;
    while (!ctx.done) {
        e = DNSServiceProcessResult(ref);
        if (e != kDNSServiceErr_NoError) { ctx.error = 3; break; }
    }
    DNSServiceRefDeallocate(ref);
    if (ctx.error || !ctx.done) return -4;
    memcpy(address, &ctx.address, sizeof(*address));
    *length = ctx.length;
    return 0;
}

static const char *nyxel_pin_callback(void *context) { return (const char *)context; }

int nyxel_pair_rppairing(const char *service_name, const char *reg_type, const char *hostname,
                         const char *pin, const unsigned char *record, size_t record_len,
                         char **error_message) {
    if (error_message) *error_message = NULL;
    struct sockaddr_storage address = {0};
    socklen_t addressLength = 0;
    int resolveResult = nyxel_resolve(service_name, reg_type, &address, &addressLength);
    if (resolveResult != 0) return resolveResult;
    void *pairing = NULL;
    IdeviceFfiError *error = rp_pairing_file_from_bytes(record, record_len, &pairing);
    if (error || !pairing) return -10;
    void *adapter = NULL;
    void *handshake = NULL;
    error = tunnel_create_rppairing((const struct sockaddr *)&address, addressLength, hostname,
                                    pairing, nyxel_pin_callback, (void *)(pin ?: "000000"),
                                    &adapter, &handshake);
    rp_pairing_file_free(pairing);
    if (error) return -11;
    if (adapter) adapter_free(adapter);
    if (handshake) rsd_handshake_free(handshake);
    return 0;
}

void nyxel_free_string(char *value) { if (value) free(value); }
