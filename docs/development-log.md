# Development log

## 2026-09-11: toolchain and first boot

The initial compiler check produced an ELF64 relocatable object for
`x86_64-unknown-none-elf`. Linking it with `answer` as the entry symbol produced
an executable ELF, but it was only a format check: the function required a caller
and was never run as a kernel.

The first boot image added the Limine revision handshake, a fixed higher-half
layout, a nonreturning C entry, and polled COM1 output. Limine supplies the stack
and page tables. The loader binary and license were pinned in `vendor/limine`.

The first QEMU launch failed with `Block node is read-only`, before kernel
execution. Adding a snapshot layer to the virtual FAT drive fixed the disk
configuration without changing the kernel. Three subsequent boots passed at
128/256/128 MiB. An interactive terminal run also reached the completion marker.

## 2026-09-17: fatal invalid-opcode handler

Added the IDT and a #UD Assembly entry that passes saved RIP to a fatal C handler.
The test resolves the UD2 symbol from its own ELF rather than hard-coding an
address, then compares both the serial diagnostic and QEMU trace against it.
Both 128/256 MiB cases passed, followed by three normal-boot regression passes.
The generic fatal fallback remained untested.

## 2026-09-17: returning timer interrupt

Added PIT/PIC IRQ0 at vector 32. The Assembly entry saves integer registers,
aligns the C call, restores the saved stack, and returns with IRETQ. The handler
increments ticks and sends master PIC EOI. Timer initialization is confined to
test images; the single-CPU test configuration disables the local APIC and HPET.

The positive cases passed five waits at 128/256 MiB with register sentinels,
CF/DF restoration, and clear DF inside C. QEMU independently recorded vector 32.
A masked-IRQ image produced no tick or delivery during the two-second control
observation. Normal boot and a #UD regression also passed. These tests did not
measure timer accuracy or exercise the x2APIC transition branch.

## 2026-09-21: source boundaries and reproducible checks

Moved COM1 output into a serial driver and shared the byte port-I/O primitives
between the serial and timer code. Moved deliberate UD2 and register-probe
Assembly under `tests/kernel`; those objects are linked only into their test
images. Normal-image symbol inspection confirms that the probes and test-only
DF instrumentation are absent.

Added `scripts/check.ps1` for the full regression run and explicit/environment/
PATH tool discovery. Every build now checks the final ELF for unresolved symbols.
A discovery test with a nonexistent drive exposed `Join-Path` failing before the
intended diagnostic; using filesystem path combination and an existence check
made that case report the missing tool clearly.

Verification on Windows PowerShell 5.1, Clang 23.1.1, QEMU 11.1.0:

- All eight QEMU cases passed after the source changes.
- The strengthened ordered-marker boot check passed three further boots.
- Explicit directory, environment variable, PATH, and missing-tool checks passed.
- `git diff --check` passed.

Local evidence directories (generated and excluded from Git):

- Boot: `build/test-c2f81416cc134e95acc1c9825d530597`.
- Exceptions: `build/ud2/test-a77b1fa7507a4e77ab79a479096df053`.
- Timer and masked control: `build/timer/test-5a499b9d067142eb879f12b67d9a99ea`.

Replaced the milestone worksheets with architecture, boot, exception, timer,
and test references. Corrected stale boot output and separated current behavior
from future work. No new hardware-support or memory-isolation claim is made.
