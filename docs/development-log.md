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

## 2026-09-28 - recovery from oversized input

Input exceeding 31 characters now rejects the entire line.
The kernel ignores further characters until Enter, then displays
a fresh prompt instead of halting.

Manual QEMU tests passed:
- The 32nd character triggered the length error.
- Enter restored the prompt, and a new help command worked.
- help typed before ending the rejected line was discarded.
- Normal boot regression: three runs passed.

Development issue: compilation initially failed because discard_line
was used without being declared. Adding its boolean declaration fixed it.

Status: PROTOTYPE. Polling remains in use, and terminal escape
sequences are not yet supported.

## 2026-09-28 - about command - descriptive 

Added an about command describing the kernel and its current languages.
Updated help to list both commands.

Manual QEMU tests passed:
- about displayed the description.
- help listed help and about.
- abouts was rejected as an unknown command.
- The prompt returned after each response.

Debugging lesson: an extra closing brace ended a block too early,
causing several compiler errors. Removing that brace fixed compilation.


## 2026-10-24 — Command separation and automated serial tests

Moved the accidentally named header from docs into include/commands.h.
Extracted command selection to src/kernel/commands.c and formatted main.c.
Added isolated command tests and a short graphical echo launcher.

Verified: 17 command cases and 14 serial scenarios at both 128/256 MiB.
Serial tests include CR/LF/CRLF, Backspace/DEL, capacity edits, overflow
suffix discard, and recovery. All eight existing regression cases passed.
The graphical wrapper was syntax-checked, not manually operated today.

Logs:
- build/commands/test-4e1acb0ab8d7425b8bd5de099f365831/
- build/echo/test-121fc351435041a78219757b32b2dbaf/
- build/test-c324caeac5c544a8b7d85e1f51993360/
- build/ud2/test-f7eaf308b5bc4e669831338e4abe2a45/
- build/timer/test-0f5166ba50804a379420fd30db3cd44b/

Debugging: local TCP connection timed out in this environment. Replaced it
with a Windows named pipe. Initial synchronous pipe mode stalled writes while
a read was pending; asynchronous mode fixed the test transport.

No allocator, C++, scheduler or user isolation added. Monitor remains a
prototype with polling and unsupported terminal escape sequences.
See commands.md for contracts, reproduction and evidence.

## 2026-10-24 — Read-only boot memory map

Added the Limine memory-map request only to a separate memmap image. Validated
the response before reporting ranges, usable bytes and page counts. No allocator
or writes through physical addresses were added. The five missing tracked test
files were restored from HEAD with explicit user approval.

Verified 20 synthetic validator checks at each of 128/256/512 MiB.
Reported usable bytes: 82255872, 216473600, 484909056 respectively.
Host-side sums of printed usable ranges matched every summary.
Logs: build/memmap/test-a432b70ceff446db9cdb7ef74fdcc5fa/.
Existing complete 12-run regression suite also passed; normal logs:
build/test-fc46149419ae4d94b1c7c4a04aab5d2b/.

Failure: the first 64 MiB VM stopped in Limine with allocator exhaustion before
kernel entry. Kept the failing log at
build/memmap/test-0fd0230e99ea453b9325efb15a331080/ and used supported larger
test sizes. This is not a claimed kernel fix or proof of 64 MiB support.

See memory-management.md for the protocol sources, contracts, policies,
test evidence, and remaining allocation work.

## 2026-10-24 — Physical page ownership

Implemented a checked next-fit allocator for usable pages below 1 GiB, excluding page zero.
One byte per page distinguishes reserved/free/allocated; costs 256 KiB per instance.
Rejected bitmap compression for this first version to keep state transitions explicit.
No allocated-page contents are accessed and no bootloader memory is reclaimed.
Synthetic checks cover invalid maps/calls, empty pool, cap crossing, invalid/double frees,
exhaustion and reuse. Real maps are exhausted with independent uniqueness and range checks,
then all pages are returned. The final complete check.ps1 passed all 17 QEMU runs.
Allocator evidence: build/pmm/test-5508dae4de33450ab2cfeccfe5cad33e/boot-{1,2}.log.
No allocator failure occurred during this milestone; earlier tests remained passing.
Limitations: one caller, interrupts disabled, 1 GiB cap, no heap or page-content test,
no protection against stale-pointer lifetime misuse. Normal and echo images stay separate.
Lesson: allocating a physical address establishes ownership; it does not create a virtual mapping.

## 2026-10-24 — Accessing allocated pages

Added a Limine HHDM request and layout assertions. The address helper checks
alignment, capacity, response presence/revision and addition overflow. The page
pointer helper checks allocation ownership before using the trusted boot mapping.
Two allocated pages were filled and read back byte by byte using distinct patterns
and reversed patterns, then freed. No old pointer was dereferenced after free.

Final check.ps1 passed all 19 QEMU runs. Direct-map evidence:
build/directmap/test-7c2fe0d48acd4fbfa9c11ff745eede9b/boot-1.log and boot-2.log.
No build or test failure occurred during this milestone. Existing features passed.

Lesson: allocation, address translation and pointer lifetime are separate concerns.
We reuse bootloader mappings; we do not yet manage page tables or isolate programs.
The helper trusts Limine and does not prove arbitrary page-table mappings.
Normal boot and the serial monitor still do not allocate pages.
