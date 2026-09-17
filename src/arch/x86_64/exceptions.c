#include <stddef.h>
#include <stdint.h>
#include "exceptions.h"

/* Intel SDM Volume 3A, 64-bit IDT gate descriptor. */
struct __attribute__((packed)) idt_gate {
    uint16_t offset_low;
    uint16_t selector;
    uint8_t ist;
    uint8_t attributes;
    uint16_t offset_middle;
    uint32_t offset_high;
    uint32_t reserved;
};
struct __attribute__((packed)) idt_pointer {
    uint16_t limit;
    uint64_t base;
};
_Static_assert(sizeof(struct idt_gate) == 16, "Incorrect IDT gate size");
_Static_assert(offsetof(struct idt_gate, offset_high) == 8, "Incorrect IDT layout");
_Static_assert(sizeof(struct idt_pointer) == 10, "Incorrect IDTR operand size");
static struct idt_gate idt[256] __attribute__((aligned(16)));

extern void exception_ud_entry(void);
extern void exception_unhandled_entry(void);

static void set_gate(unsigned vector, void (*entry)(void), uint16_t selector)
{
    const uintptr_t address = (uintptr_t)entry;
    idt[vector].offset_low = (uint16_t)address;
    idt[vector].selector = selector;
    idt[vector].ist = 0; /* Current stack; no IST or privilege transition yet. */
    idt[vector].attributes = 0x8e; /* Present, DPL 0, 64-bit interrupt gate. */
    idt[vector].offset_middle = (uint16_t)(address >> 16);
    idt[vector].offset_high = (uint32_t)(address >> 32);
    idt[vector].reserved = 0;
}

void exceptions_init(void)
{
    uint16_t selector;
    __asm__ volatile ("cli" : : : "memory");
    /* Reuse the currently valid kernel code descriptor supplied by Limine. */
    __asm__ volatile ("movw %%cs, %0" : "=r"(selector));
    for (unsigned vector = 0; vector < 256; ++vector) {
        set_gate(vector, exception_unhandled_entry, selector);
    }
    set_gate(6, exception_ud_entry, selector);
    const struct idt_pointer pointer = {
        .limit = (uint16_t)(sizeof(idt) - 1),
        .base = (uintptr_t)idt
    };
    __asm__ volatile ("lidt %0" : : "m"(pointer) : "memory");
    /* Keep maskable interrupts disabled until device handling exists. */
}
