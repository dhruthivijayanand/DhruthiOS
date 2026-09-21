# Architecture

DhruthiOS is a single-address-space kernel for QEMU's x86-64 PC model. All current
code runs at kernel privilege on one CPU. There are no processes or system calls.

## Source layout

| Location | Responsibility |
| --- | --- |
| `src/kernel/main.c` | Boot handshake, initialization order, fatal diagnostics |
| `src/drivers/serial.c` | Polled COM1 output |
| `include/arch/x86_64/io.h` | Byte-sized port I/O primitives |
| `src/arch/x86_64/exceptions.c` | IDT layout and gate installation |
| `src/arch/x86_64/exceptions.S` | Fatal exception entry stubs |
| `src/arch/x86_64/timer.c` | PIC/PIT setup, tick state, EOI |
| `src/arch/x86_64/timer.S` | Register preservation and interrupt return |
| `tests/kernel/` | Deliberate fault and register-preservation probes |
| `config/` | ELF layout and Limine configuration |
| `scripts/` | Native Windows build and QEMU test entry points |

C calls follow the x86-64 System V ABI, even though the compiler runs on Windows.
Assembly bridges CPU interrupt frames to that ABI. No hosted C library, C++
runtime, allocator, or dynamic linker is linked into the image.

## Initialization order

1. Limine maps the kernel and supplies an initial stack and CPU state.
2. `kmain` configures serial output and checks the base-revision handshake.
3. `exceptions_init` installs the IDT while maskable interrupts are disabled.
4. Normal boot logs completion and halts. Test images instead exercise #UD or
   configure IRQ0 and enter the register-preservation probe.

The serial driver does not acquire locks. Timer handlers never call it, and
current callers serialize writes on the single CPU. A future interrupt-driven
console or SMP implementation must revisit this contract.

## Memory and failure handling

The kernel uses Limine's mappings and stack without reclamation. It has static
storage and stack-local objects but no heap. The writable tick count is accessed
with interrupts disabled outside its handler. This design is specific to one CPU.

Fault handlers use the current stack. There is no alternate stack for stack
failure, and the generic handler cannot identify a faulting vector. Serial
output has bounded polling, but no independent fallback device. These limits
matter more than adding another device driver: memory allocation and stronger
fault diagnostics are the next architectural work.

## Build variants

| Mode | Output directory | Execution |
| --- | --- | --- |
| `normal` | `build/` | Initialization and halt |
| `ud2` | `build/ud2/` | Deliberate invalid instruction |
| `timer` | `build/timer/` | Five checked interrupt-return waits |
| `timer-masked` | `build/timer-masked/` | Wait with IRQ0 masked |

Each variant has its own ELF and boot directory. The deliberate UD2 and register
probe Assembly are linked only into their corresponding test images. Normal
boot retains the timer gate and driver, but does not initialize the timer.
