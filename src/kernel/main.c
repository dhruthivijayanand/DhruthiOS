#include <stdbool.h>
#include <stdint.h>
#include "exceptions.h"
#include "timer.h"
#include "serial.h"
#if defined(DHRUTHIOS_TEST_UD2) || defined(DHRUTHIOS_TEST_TIMER)
#include "kernel-tests.h"
#endif

/* Limine protocol markers and base revision, from the protocol specification.
 * The linker preserves these arrays in this order. They are not CPU opcodes. */
__attribute__((used, section(".limine_start"), aligned(8)))
static volatile uint64_t requests_start[] = {
    0xf6b8f4b39de7d1ae, 0xfab91a6940fcb9cf,
    0x785c6ed015d3e316, 0x181e920a7852b9d9
};
__attribute__((used, section(".limine_requests"), aligned(8)))
static volatile uint64_t base_revision[] = {
    0xf9562b2d5c95a6c8, 0x6a7b384944536bdc, 6
};
__attribute__((used, section(".limine_end"), aligned(8)))
static volatile uint64_t requests_end[] = {
    0xadc0e0531bb10d03, 0x9572709f31764c62
};

static _Noreturn void halt_forever(void)
{
    for (;;) {
        __asm__ volatile ("cli; hlt" : : : "memory");
    }
}

_Noreturn void exception_panic_ud(uint64_t rip)
{
    static const char digits[] = "0123456789abcdef";
    char address[19] = "0x0000000000000000";
    for (unsigned i = 0; i < 16; ++i) {
        address[17 - i] = digits[(rip >> (i * 4)) & 0xf];
    }
    (void)serial_write("PANIC: #UD invalid opcode (vector 6)\r\nRIP: ");
    (void)serial_write(address);
    (void)serial_write("\r\nDhruthiOS: exception handler reached; halting\r\n");
    halt_forever();
}

_Noreturn void exception_panic_unhandled(void)
{
    (void)serial_write("PANIC: unhandled exception or interrupt; halting\r\n");
    halt_forever();
}

_Noreturn void kmain(void)
{
    serial_init();
    if (base_revision[2] != 0) {
        (void)serial_write("DhruthiOS: unsupported Limine base revision\r\n");
        halt_forever();
    }
    if (!serial_write("DhruthiOS: kernel entered\r\n")) {
        halt_forever();
    }
    exceptions_init();
    (void)serial_write("Hello Dhruthi! I am running inside your kernel. \r\n");
    (void)serial_write("DhruthiOS: IDT loaded\r\n");
#ifdef DHRUTHIOS_TEST_UD2
    (void)serial_write("TEST: triggering UD2\r\n");
    exception_test_ud();
    (void)serial_write("FAIL: UD2 returned unexpectedly\r\n");
    halt_forever();
#endif
#ifdef DHRUTHIOS_TEST_TIMER
    timer_init();
    (void)serial_write("TEST: timer configured; waiting for IRQ0\r\n");
    for (unsigned iteration = 0; iteration < 5; ++iteration) {
        const uint64_t before = timer_ticks();
        if (!timer_wait_probe() || !timer_handler_state_ok() || timer_ticks() <= before) {
            (void)serial_write("FAIL: timer return or saved state check\r\n");
            halt_forever();
        }
        (void)serial_write("TICK: IRQ0 returned; registers and flags preserved\r\n");
    }
    (void)serial_write("PASS: five timer waits completed; kernel execution resumed\r\n");
    halt_forever();
#endif
#ifdef DHRUTHIOS_TEST_ECHO
/* Next milestone: literally just collect a bounded line of input before processing it. */
 char line[32];
    unsigned length = 0;
    bool previous_was_cr = false;

    if (!serial_write("ECHO: type a short line, then press Enter\r\n")) {
        halt_forever();
    }

    for (;;) {
        char character;
        if (!serial_try_read(&character)) {
            continue;
        }
        if (previous_was_cr && character == '\n') {
    previous_was_cr = false;
    continue;
}
previous_was_cr = (character == '\r');
if (character == '\b' || character == 127) {
    if (length > 0) {
        --length;
        if (!serial_write("\b \b")) {
            halt_forever();
        }
    }
    continue;
}

        if (character == '\r' || character == '\n') {
            line[length] = '\0';
            if (!serial_write("\r\n")) {
    halt_forever();
}

            const char *response = "Unknown command. Try help.\r\n";

if (length == 0) {
    response = "No command entered.\r\n";
} else if (length == 4 &&
           line[0] == 'h' &&
           line[1] == 'e' &&
           line[2] == 'l' &&
           line[3] == 'p') {
    response = "Commands:\r\n  help - show this message\r\n";
}

if (!serial_write(response)) {
    halt_forever();
}

length = 0;
if (!serial_write("DhruthiOS> ")) {
    halt_forever();
}
continue;
        }

        if (character < ' ' || character > '~') {
            continue;
        }

        if (length >= sizeof(line) - 1) {
            (void)serial_write("ECHO: line too long; stopping\r\n");
            halt_forever();
        }

        line[length] = character;
        ++length;

        char visible[2] = { character, '\0' };
if (!serial_write(visible)) {
    halt_forever();
}
    }
#endif
(void)serial_write("DhruthiOS: boot protocol accepted; CPU halted\r\n");
    halt_forever();
}

