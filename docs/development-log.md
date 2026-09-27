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
## 2026-09-24 — Single-character serial echo

Added a function that checks for incoming serial data and reads one
character when available. A separate echo build prints that character
back, then halts. The normal build keeps its original startup behaviour.

Verification:
- Manual QEMU test: typed a and observed "ECHO: received [a]".
- Normal boot regression: passed at 128, 256, and 128 MiB RAM.
- Logs: build/test-9396f540afac42959fa16a48e53d5740/

Status: PROTOTYPE. One printable character tested manually.
No shell or physical keyboard driver yet. The echo test actively polls
while waiting; input error handling and broader input tests remain. 

## 2026-09-27 - this concerns bounded serial input

Extended echo mode to collect a line in a 32-byte buffer:
up to 31 printable characters plus the end-of-text marker.

Manual QEMU tests passed:
- "help" was echoed correctly.
- Empty input produced [].
- Exactly 31 characters were accepted.
- The 32nd character produced "line too long; stopping".

Normal boot regression: three runs passed after restoring the
completion message expected by the test.

Debugging lesson: the initial regression failure was an exact-text
mismatch. The log showed that the kernel reached its final message.

Status: PROTOTYPE. Input is polled, typing is not displayed immediately,
Backspace is unsupported, and the kernel stops after one line.
This collects text; it does not execute commands yet.

## 2026-09-28 - first command handling

Added exact matching for the help command in the separate echo build.

Manual QEMU tests:
- help displayed the command description.
- helpful produced "Unknown command. Try help."
- Empty input produced "No command entered."

Normal boot: all three logs contained the expected startup markers.
Logs: build/test-665817157c8343d8a2dea3c9226b47c5/

Status: PROTOTYPE. Handles one command, then halts.
No repeated prompt, live typing display, or Backspace support yet.

## 2026-09-28 - repeated command prompt

After each command, the kernel resets the input length, displays
DhruthiOS>, and checks for more input instead of halting.

Manual QEMU tests passed in one session:
- help, hello, help produced the expected responses.
- Empty input produced "No command entered."
- help still worked after empty input.
- The prompt returned after each response.

Normal boot regression: three runs passed.

Added handling intended to treat CR followed by LF as one line ending.
Separate CR, LF, and CRLF injection tests remain unperformed.

Status: PROTOTYPE. Typing remains invisible until Enter.
Backspace is unsupported so oversized input still halts the kernel. 
## 2026-09-28 - visible typing and backspace
a series of editing tests that passed
Characters now appear as they are typed. Enter moves the response
onto a new line. Backspace reduces the accepted input length and
erases the displayed character.

Manual QEMU tests passed:
- help appeared while typing and produced the expected response.
- helx, Backspace, p was interpreted as help.
- Backspace on empty input preserved the prompt.
- Erasing abc completely, then pressing Enter, produced
  "No command entered."
- Normal boot regression: three runs passed.

Status: PROTOTYPE. Oversized input still halts the kernel.
Arrow keys and other terminal escape sequences are not supported.


