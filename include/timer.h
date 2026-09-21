#ifndef DHRUTHIOS_TIMER_H
#define DHRUTHIOS_TIMER_H
#include <stdbool.h>
#include <stdint.h>

/* One CPU, legacy QEMU PC. Call with IF clear and IDT already installed. */
void timer_init(void);
uint64_t timer_ticks(void); /* Read with IF clear. */
void timer_on_irq(void);   /* Called only by timer_irq_entry. */
void timer_irq_entry(void);
#endif
