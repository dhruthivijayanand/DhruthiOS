# First boot: explanation and reproduction

## STEP 1 — CONCEPT

Firmware is the software that first initializes the virtual machine. It finds
the UEFI bootloader at EFI/BOOT/BOOTX64.EFI. Limine then reads limine.conf, loads
kernel.elf, and transfers control to kmain. We wrote the kernel, not the firmware
or bootloader. QEMU emulates the machine on Windows using TCG.

## STEP 2 — WHY

An ELF executable does not establish its own CPU environment. Our kernel needs
the loader's documented 64-bit machine state, initial stack, and memory mappings.
We must not return from kmain: Limine supplies an invalid return address, not an
ordinary caller to return to.

## STEP 3 — ARCHITECTURE

Windows tools -> kernel.elf -> project boot directory -> QEMU virtual FAT disk
-> QEMU UEFI firmware -> Limine -> C kmain -> serial port -> host terminal.

## STEP 4 — DESIGN

We select UEFI because this QEMU installation already includes the necessary
firmware. QEMU builds a FAT view of build/esp, so there is no ISO builder or
real-disk installation. snapshot=on supplies temporary guest writes over the
read-only FAT backing directory. Do not edit/rebuild that directory while QEMU
is running. Do not use the monitor's commit command to persist guest writes.

The ELF has separate writable protocol records, executable code, and read-only
constant data. The linker sets the start of the image at virtual address
0xffffffff80000000, within the required Limine range. This is not a physical
RAM address; we did not choose where the loader places the image in RAM.
We use the loader's page tables and stack and do not reclaim their memory.

## STEP 5 — CODE

Exact source files and purposes:
- src/kernel/main.c: complete entry, revision handshake, serial output, halt loop.
- config/kernel.ld: entry symbol, virtual layout, segment flags and alignment.
- config/limine.conf: selects the kernel and four-level paging.
- scripts/build.ps1: exact compiler/linker commands and boot-file packaging.
- scripts/run.ps1: exact interactive QEMU invocation.
- scripts/test-boot.ps1: automated, bounded serial-output smoke test.
- vendor/limine/BOOTX64.EFI: upstream loader; LICENSE and PROVENANCE.md accompany it.

Read main.c in this order: kmain, serial_write, serial_init, inb/outb,
halt_forever, then the protocol arrays.

### Understanding main.c

`_Noreturn void kmain(void)` says this function takes no arguments and never
returns. The serial device is configured first so revision failure can be logged.
The bootloader changes base_revision[2] to zero when it accepts revision 6.
We check that value before announcing success.

The marker arrays are 64-bit numbers specified by Limine, not invented addresses
or CPU instructions. The compiler's `used` attribute emits them; linker KEEP
preserves them. Eight-byte alignment satisfies the protocol. `volatile` prevents
the revision read from being replaced by its compile-time initializer; it is not
a lock or a general hardware memory barrier.

`const char *text` points to a character sequence we do not modify. `*text` reads
the current character; `text++` advances to the next one. The terminating zero
marks the end of the string. The strings passed here are known static literals.
This routine does not validate arbitrary external pointers.

COM1's I/O-port base is 0x3f8 for the selected QEMU PC serial device. These are I/O
port numbers, not RAM addresses. OUTB writes one byte and INB reads one byte.
Inline Assembly is needed because standard C has no port-I/O operation. The
constraints put bytes in AL and choose an immediate port or DX. The memory
clobber constrains compiler reordering; it is not a CPU fence instruction.

UART offsets: +0 data/divisor-low; +1 interrupt-enable/divisor-high; +2 FIFO
control; +3 line control; +4 modem control; +5 line status. DLAB in line control
selects access to the divisor. We choose divisor 1, 8 data bits, no parity, one
stop bit. Before each byte, bit 5 of line status must indicate the transmit
holding register is empty. The driver polls with a finite attempt limit, not a
wall-clock timeout. If output fails, the kernel halts; it has no second diagnostic
channel. CR/LF ends each terminal line.

CLI disables maskable interrupts; HLT pauses instruction execution until a
qualifying wake event. The enclosing loop prevents returning if execution resumes.
CLI does not block exceptions or non-maskable interrupts. There are no kernel
exception handlers yet; unexpected faults can still terminate the guest.

### Understanding the build flags

- --target and -ffreestanding: bare-metal target and language assumptions.
- -fno-pic/-fno-pie, -mcmodel=kernel: fixed higher-half kernel code model.
- -mno-red-zone: do not use the ABI's below-stack scratch area, unsuitable for
  our planned interrupt-handling kernel.
- -mgeneral-regs-only: avoid compiler-generated FP/SIMD use in this early kernel.
- -fno-stack-protector: we have no stack-canary runtime yet; this removes a
  dependency, not buffer-overflow risk.
- -fno-unwind-tables/-fno-asynchronous-unwind-tables: no unwinding service here.
- -O2 -g: optimize machine code and retain debugging information.
- -Wall -Wextra -Werror: requested warnings must be resolved.
- -nostdlib -static: explicit static link without hosted libraries.
- -T and max-page-size: use our layout and 4096-byte maximum segment alignment.

The linker flags 6, 5, 4 mean read/write, read/execute, and read-only respectively.
These describe kernel ELF mappings, not a complete security architecture. Limine
also supplies a direct map; no general W^X or application isolation is claimed.

## STEP 6 — BUILD

In PowerShell, from the DhruthiOS repository:

```powershell
& ./scripts/build.ps1
```

The exact commands are in the script, which stops on failed compilation/linking.
LLVM location can be changed with -LlvmBin. No external downloads occur.

## STEP 7 — RUN

```powershell
& ./scripts/run.ps1
```

This starts QEMU in the terminal. Ctrl+A, release, then X quits QEMU. Stop it
before building again. The script accepts -QemuDir for another installation.
It selects one CPU, 128 MiB RAM, TCG, read-only firmware, a temporary disk write
layer, no network, and serial/monitor output on the terminal. No host physical
disk is passed through.

## STEP 8 — VERIFY

Expected kernel lines, possibly after firmware output:

```
DhruthiOS: kernel entered
DhruthiOS: boot protocol accepted; CPU halted
```

The second line is printed immediately before entering the halt loop. The text
alone is not an independent CPU-state measurement. The automated smoke test
checks both output markers, process liveness when observed, and QEMU stderr:

```powershell
& ./scripts/test-boot.ps1
```

It tries fresh VM boots with 128, 256, and 128 MiB RAM and stops each test VM
after receiving the markers, or after a 30-second timeout. This is limited
emulator evidence, not real-hardware or production reliability certification.

## STEP 9 — DEBUG

Compiler errors: inspect source and flags; stop before running an older build.
QEMU startup errors: inspect paths, firmware, and disk options.
Firmware without kernel markers: inspect boot directory and Limine configuration.
Unsupported revision: compare pinned loader and requested protocol version.
Silence after handoff: inspect serial configuration and use QEMU/GDB in a later
debugging milestone. Do not rewrite the whole kernel.

Observed first failure: `Block node is read-only` before firmware ran. QEMU's
disk setup rejected a read-only disk. A temporary snapshot layer over the
read-only virtual FAT source fixed the configuration; kernel code was unchanged.

## STEP 10 — DOCUMENT

DOCUMENT THIS: division of firmware/loader/kernel responsibilities, entry contract,
serial polling, UEFI selection, test evidence, and the actual disk startup failure.
DO NOT BOTHER DOCUMENTING THIS: memorizing marker constants or every boot attempt.
INTERVIEW-WORTHY: why the kernel cannot return, why printf is absent, how port I/O
differs from RAM access, and which initialization was delegated to Limine.

## STEP 11 — GIT

Commit the verified milestone as `Boot x86-64 kernel with Limine and serial output`.
Generated builds and logs remain ignored; source, scripts, provenance, and the
licensed loader are versioned. Earlier compiler probes remain intact.

## Authoritative references

- Limine protocol: https://github.com/limine-bootloader/limine-protocol/blob/trunk/PROTOCOL.md
- Limine 12.5.2 configuration: https://github.com/limine-bootloader/limine/blob/v12.5.2/CONFIG.md
- QEMU virtual FAT and snapshots: https://www.qemu.org/docs/master/system/images.html
- QEMU options: https://www.qemu.org/docs/master/system/invocation.html
- QEMU 11.1.0 UART implementation: https://github.com/qemu/qemu/blob/v11.1.0/hw/char/serial.c
- QEMU PC UART port assignment: https://github.com/qemu/qemu/blob/v11.1.0/hw/char/serial-isa.c
- Intel instruction reference (IN, OUT, CLI, HLT): https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html
