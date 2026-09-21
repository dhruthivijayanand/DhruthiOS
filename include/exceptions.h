#ifndef DHRUTHIOS_EXCEPTIONS_H
#define DHRUTHIOS_EXCEPTIONS_H
#include <stdint.h>

void exceptions_init(void);
/* Assembly entry points call these C functions; neither returns. */
_Noreturn void exception_panic_ud(uint64_t rip);
_Noreturn void exception_panic_unhandled(void);
#endif
