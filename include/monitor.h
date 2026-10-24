#ifndef DHRUTHIOS_MONITOR_H
#define DHRUTHIOS_MONITOR_H
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
bool monitor_init(void);
/* One caller, IF clear; input is a readable span of length bytes.
 * Returns false on fatal service or serial error; caller must halt. */
bool monitor_execute(const char *line, unsigned length);
#ifdef __cplusplus
}
#endif
#endif
