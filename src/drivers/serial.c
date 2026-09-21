#include "serial.h"
#include "arch/x86_64/io.h"

enum { COM1 = 0x3f8, TRANSMIT_READY = 0x20, POLL_LIMIT = 1000000 };

void serial_init(void)
{
    outb(COM1 + 1, 0x00); /* Disable UART interrupts: this driver polls. */
    outb(COM1 + 3, 0x80); /* Enable access to baud-rate divisor registers. */
    outb(COM1 + 0, 0x01); /* Divisor low byte: 115200 baud for this UART. */
    outb(COM1 + 1, 0x00); /* Divisor high byte. */
    outb(COM1 + 3, 0x03); /* 8 data bits, no parity, 1 stop bit; clear DLAB. */
    outb(COM1 + 2, 0x07); /* Enable FIFO, clear receive/transmit FIFOs. */
    outb(COM1 + 4, 0x03); /* Assert DTR and RTS; no loopback. */
}

bool serial_write(const char *text)
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
