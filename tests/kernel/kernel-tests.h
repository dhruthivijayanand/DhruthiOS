#ifndef DHRUTHIOS_KERNEL_TESTS_H
#define DHRUTHIOS_KERNEL_TESTS_H
#include <stdbool.h>

void exception_test_ud(void);
/* Returns with IF and DF clear; verifies state restored by IRQ0 entry/exit. */
bool timer_wait_probe(void);
bool timer_handler_state_ok(void);
bool command_tests_run(void);
bool memory_map_tests_run(void);
#endif
