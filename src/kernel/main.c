#include <stdbool.h>
#include <stdint.h>

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

enum { COM1 = 0x3f8, TRANSMIT_READY = 0x20, POLL_LIMIT = 1000000 };

static void outb(uint16_t port, uint8_t value)
{
    __asm__ volatile ("outb %0, %1" : : "a"(value), "Nd"(port) : "memory");
}

static uint8_t inb(uint16_t port)
{
    uint8_t value;
    __asm__ volatile ("inb %1, %0" : "=a"(value) : "Nd"(port) : "memory");
    return value;
}

static _Noreturn void halt_forever(void)
{
    for (;;) {
        __asm__ volatile ("cli; hlt" : : : "memory");
    }
}

static void serial_init(void)
{
    outb(COM1 + 1, 0x00); /* Disable UART interrupts: this driver polls. */
    outb(COM1 + 3, 0x80); /* Enable access to baud-rate divisor registers. */
    outb(COM1 + 0, 0x01); /* Divisor low byte: 115200 baud for this UART. */
    outb(COM1 + 1, 0x00); /* Divisor high byte. */
    outb(COM1 + 3, 0x03); /* 8 data bits, no parity, 1 stop bit; clear DLAB. */
    outb(COM1 + 2, 0x07); /* Enable FIFO, clear receive/transmit FIFOs. */
    outb(COM1 + 4, 0x03); /* Assert DTR and RTS; no loopback. */
}

static bool serial_write(const char *text)
{
    while (*text != '\0') {
        unsigned attempts = 0;
        while ((inb(COM1 + 5) & TRANSMIT_READY) == 0) {
            if (++attempts == POLL_LIMIT) {
                return false; /* Bounded attempts, not a calibrated timer. */
            }
        }
        outb(COM1, (uint8_t)*text++);
    }
    return true;
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
    (void)serial_write("DhruthiOS: boot protocol accepted; CPU halted\r\n");
    halt_forever();
}
