#include "timer.h"
#include "arch/x86_64/io.h"

enum { PIC1_COMMAND = 0x20, PIC1_DATA = 0x21,
       PIC2_COMMAND = 0xa0, PIC2_DATA = 0xa1,
       PIT_CHANNEL0 = 0x40, PIT_COMMAND = 0x43, PIT_DIVISOR = 11932 };
static volatile uint64_t ticks;
#ifdef DHRUTHIOS_TEST_TIMER
static volatile bool bad_direction_flag;
#endif

static void select_legacy_pic(void)
{
    uint32_t a, b, c, d;
    __asm__ volatile ("cpuid" : "=a"(a), "=b"(b), "=c"(c), "=d"(d)
                      : "a"(1), "c"(0));
    if ((d & (1u << 9)) != 0) {
        uint32_t low, high;
        __asm__ volatile ("rdmsr" : "=a"(low), "=d"(high) : "c"(0x1b));
        /* Disable local APIC (and x2APIC mode if active) for direct PIC delivery.
         * This is a deliberate single-CPU PC design, not an APIC driver. */
        low &= ~((1u << 11) | (1u << 10));
        __asm__ volatile ("wrmsr" : : "c"(0x1b), "a"(low), "d"(high) : "memory");
    }
}

void timer_init(void)
{
    __asm__ volatile ("cli" : : : "memory");
    ticks = 0;
#ifdef DHRUTHIOS_TEST_TIMER
    bad_direction_flag = false;
#endif
    select_legacy_pic();
    outb(PIC1_DATA, 0xff);
    outb(PIC2_DATA, 0xff);
    /* ICW1: begin cascaded, edge-triggered initialization with ICW4 to follow. */
    outb(PIC1_COMMAND, 0x11);
    outb(PIC2_COMMAND, 0x11);
    outb(PIC1_DATA, 0x20); /* Master IRQ0..7 -> vectors 32..39. */
    outb(PIC2_DATA, 0x28); /* Slave IRQ8..15 -> vectors 40..47. */
    outb(PIC1_DATA, 0x04); /* Slave connected to master IRQ2. */
    outb(PIC2_DATA, 0x02); /* Slave's cascade identity is 2. */
    outb(PIC1_DATA, 0x01); /* 8086 mode, explicit EOI. */
    outb(PIC2_DATA, 0x01);
    outb(PIC1_DATA, 0xff);
    outb(PIC2_DATA, 0xff);
    /* Channel 0, low then high divisor bytes, mode 2, binary counter.
     * QEMU PIT input 1193182 Hz / 11932 is approximately 100 Hz. */
    outb(PIT_COMMAND, 0x34);
    outb(PIT_CHANNEL0, (uint8_t)PIT_DIVISOR);
    outb(PIT_CHANNEL0, (uint8_t)(PIT_DIVISOR >> 8));
#ifndef DHRUTHIOS_TIMER_MASKED
    outb(PIC1_DATA, 0xfe); /* Unmask only IRQ0. All other IRQs stay masked. */
#endif
    /* No physical-hardware I/O delays: this driver targets QEMU's virtual PIC. */
}

void timer_on_irq(void)
{
#ifdef DHRUTHIOS_TEST_TIMER
    uint64_t flags;
    __asm__ volatile ("pushfq; popq %0" : "=r"(flags) : : "memory");
    if ((flags & (1u << 10)) != 0) { bad_direction_flag = true; }
#endif
    ++ticks;
    outb(PIC1_COMMAND, 0x20); /* IRQ0: master PIC EOI only. */
}

uint64_t timer_ticks(void) { return ticks; }
#ifdef DHRUTHIOS_TEST_TIMER
bool timer_handler_state_ok(void) { return !bad_direction_flag; }
#endif
