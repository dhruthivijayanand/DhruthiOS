# Architecture

DhruthiOS is a single-address-space kernel for QEMU's x86-64 PC model. All current
code runs at kernel privilege on one CPU. There are no processes or system calls.

## Source layout

| Location | Responsibility |
| --- | --- |
| `src/kernel/main.c` | Boot handshake, initialization, fatal diagnostics, bounded input loop |
| `src/kernel/commands.c` | Hardware-independent command response selection |
| `src/drivers/serial.c` | Polled COM1 input/output |
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
runtime or dynamic linker is linked into the image. The monitor includes our C physical-page allocator and a limited C++ command component.

## Initialization order

1. Limine maps the kernel and supplies an initial stack and CPU state.
2. `kmain` configures serial output and checks the base-revision handshake.
3. `exceptions_init` installs the IDT while maskable interrupts are disabled.
4. Normal boot logs completion and halts. Test images instead exercise #UD or
   configure IRQ0 and enter the register-preservation probe. The echo image runs
   the legacy serial interface; the commands image tests response selection.
5. The monitor image initializes a physical-page pool, then runs the shared input
   loop with C++ help/about/memory/memtest commands. It initializes the timer, enables IRQ0 while waiting, and keeps interrupts disabled during service calls.

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


## Integrated memory services

src/memory/memory_map.c validates the boot map. src/memory/pmm.c tracks free and
allocated 4096-byte pages below 1 GiB using one byte per page. Only usable memory
enters the pool; page zero, reserved regions and loader data remain excluded.
src/memory/direct_map.c discovers Limine's mapping offset and issues borrowed
pointers only for allocated pages. No page tables are created or reclaimed.

src/kernel/monitor.cpp calls these C services through C language linkage.
include/text_buffer.hpp provides fixed-capacity C++ formatting without a heap
or standard library. Global construction and exit-time destruction are forbidden
by compiler warnings treated as errors. The monitor's memtest borrows two pages,
checks their contents, returns them, and verifies the initial free count.

Additional modes: echo (legacy monitor), commands, memmap, pmm, directmap, format
(C++ boundary tests), and monitor (integrated demo). Each uses build/<mode>/.
See [monitor.md](monitor.md) for design, testing and explicit limitations.

The final monitor adds ticks and timer wakeups. Serial polling occurs after each
idle wake; no allocator or serial service is called from the timer handler.
