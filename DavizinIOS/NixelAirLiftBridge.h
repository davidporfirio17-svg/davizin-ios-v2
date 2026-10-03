#ifndef NYXEL_AIRLIFT_BRIDGE_H
#define NYXEL_AIRLIFT_BRIDGE_H
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
int nyxel_pair_rppairing(const char *service_name, const char *reg_type, const char *hostname,
                         const char *pin, const unsigned char *record, size_t record_len,
                         char **error_message);
void nyxel_free_string(char *value);
#ifdef __cplusplus
}
#endif
#endif
