# Boot and kernel entry

## Handoff

QEMU exposes `build/esp` as a virtual FAT disk. Its bundled UEFI firmware starts
`EFI/BOOT/BOOTX64.EFI`; Limine reads `limine.conf`, loads `kernel.elf`, and enters
`kmain` in 64-bit mode. The kernel relies on the loader's initial stack, code
segment, and page tables. It does not supply a custom bootloader.

The protocol records in `src/kernel/main.c` request Limine base revision 6.
They use the protocol's marker values and eight-byte alignment. The compiler's
`used` attribute emits them, and the linker script keeps them in order. Limine
sets the revision field to zero on acceptance; `kmain` checks it before continuing.
The entry point never returns.

The QEMU disk uses a temporary snapshot layer. Guest writes do not update the
boot directory. Do not modify that directory while the VM is running. No host
physical disk is attached by the scripts.

## ELF layout

`config/kernel.ld` sets the image's virtual base to `0xffffffff80000000` and the
entry symbol to `kmain`. The base is not a physical load address. Sections are
assigned to separate loadable segments:

| Contents | ELF permissions |
| --- | --- |
| Limine records | Read/write |
| `.text` | Read/execute |
| `.rodata` | Read-only |
| `.data` and `.bss` | Read/write |

Segment boundaries are aligned to 4096 bytes. The kernel neither replaces the
loader's mappings nor reclaims its memory. These ELF permissions alone do not
establish a system-wide W^X policy.

## Serial diagnostics

The serial driver uses QEMU PC's COM1 at I/O port `0x3f8`. Initialization selects
8 data bits, no parity, one stop bit, divisor 1, and FIFO operation. UART
interrupts remain disabled. Each transmitted byte waits for bit 5 of the line
status register, with a limit of one million polling attempts.

`serial_write` accepts a valid NUL-terminated kernel string and returns false
if the transmitter does not become ready. This is an attempt limit, not a timed
deadline. There is no second diagnostic device if serial output fails. The
panic path makes a best effort to log and then halts.

## Build contract

Clang targets `x86_64-unknown-none-elf` explicitly. The Windows target would
produce the wrong object format. C is compiled freestanding and linked without
hosted libraries. Freestanding compilation does not eliminate all possible
compiler runtime calls; the build checks the final ELF for unresolved symbols.

The kernel code model and disabled PIC/PIE match the fixed higher-half layout.
The red zone is disabled because an interrupt may use the current stack.
`-mgeneral-regs-only` keeps compiler-generated FP/SIMD code out of handlers;
interrupt entry currently saves only integer registers. Stack protection and
unwinding are disabled because their runtimes are not provided. Builds retain
debug information and treat warnings as errors.

## References

- [Limine protocol](https://github.com/limine-bootloader/limine-protocol/blob/trunk/PROTOCOL.md): revision handshake and entry state.
- [Limine 12.5.2 configuration](https://github.com/limine-bootloader/limine/blob/v12.5.2/CONFIG.md).
- [Clang freestanding builds](https://clang.llvm.org/docs/UsersManual.html#freestanding-builds).
- [QEMU virtual FAT disks](https://www.qemu.org/docs/master/system/images.html#virtual-fat-disk-images).
- [QEMU 11.1.0 UART](https://github.com/qemu/qemu/blob/v11.1.0/hw/char/serial.c) and [PC port assignment](https://github.com/qemu/qemu/blob/v11.1.0/hw/char/serial-isa.c).
