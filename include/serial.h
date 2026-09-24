#ifndef DHRUTHIOS_SERIAL_H
#define DHRUTHIOS_SERIAL_H
#include <stdbool.h>

void serial_init(void);
/* Valid NUL-terminated kernel string; false on transmit polling exhaustion.
 * No locking: callers must serialize access on the single supported CPU. */
bool serial_write(const char *text);
bool serial_try_read(char *character);
#endif

