# Milestone: fatal invalid-opcode exception reporting

## STEP 1 — CONCEPT

A CPU exception transfers execution to a handler. UD2 deliberately raises
invalid-opcode exception 6 (#UD). The IDT tells the CPU where its handler is.

## STEP 2 — WHY

Report a fault and its instruction address instead of losing all diagnostic
information. Reporting a fault is not recovering from it.

## STEP 3 — ARCHITECTURE

UD2 -> IDT[6] -> Assembly entry -> C diagnostic -> halt loop.
Maskable device interrupts stay disabled. This is not a timer or keyboard driver.

## STEP 4 — DESIGN

Use 256 gates, with a specific #UD handler and a generic fatal fallback elsewhere.
The fallback ignores the CPU frame, including any error code, and never returns.
It does not identify the vector and has not been tested. Limine's current code
selector and stack are reused. No TSS/IST, alternate fault stack, user-mode
transition, nested-fault recovery, or returning interrupt support is claimed.

## STEP 5 — CODE

Exact source/changes are in these files:
- include/exceptions.h: declarations shared by C and Assembly.
- src/arch/x86_64/exceptions.c: packed 16-byte gates, 10-byte IDTR operand,
  compile-time layout checks, gate installation and LIDT.
- src/arch/x86_64/exceptions.S: Assembly entry routines and deliberate UD2.
- src/kernel/main.c: calls exceptions_init and prints fatal diagnostics and RIP.
- scripts/build.ps1: builds C/Assembly and separates normal from ud2 outputs.
- scripts/test-exception.ps1: automatic build, QEMU test, evidence checks and cleanup.
- scripts/test-boot.ps1: normal-boot regression also checks the IDT-loaded marker.

Each gate splits the handler address across three fields. Attributes 0x8e select
a present, DPL-0 interrupt gate. IST and reserved fields are zero. IDTR's limit
is the table's size minus one. The table has static lifetime.

For #UD, the CPU pushes no error code: saved RIP is at (%rsp). The stub moves
it into RDI (first integer argument), clears the direction flag with CLD and
aligns RSP to 16 bytes before calling C. The C function prints a fixed-width
hexadecimal address with a bounded local buffer and enters the halt loop.

The fatal stub does not preserve all registers or execute IRETQ. It is valid only
for this nonreturning path. A future returning IRQ handler needs more machinery.

exception_test_ud begins with UD2, so its symbol address must equal saved RIP.
A following RET allows detection if a future broken handler skips the fault:
kmain would then print an explicit failure. No C undefined behavior is used to
generate the deliberate exception.

## STEP 6 — BUILD

From the repository in PowerShell:

```powershell
& ./scripts/build.ps1 -Mode ud2
```

Test files go to build/ud2, without replacing the normal build/esp. Default
`& ./scripts/build.ps1` still builds the normal kernel. Exact commands and flags
are in the build script.

## STEP 7 — RUN

This one command builds the test, runs it twice, and stops its own QEMU processes:

```powershell
& ./scripts/test-exception.ps1
```

The exact QEMU command is in the script. It uses TCG, UEFI and the established
virtual FAT setup, now pointing at build/ud2/esp. `-d int -D <log>` records CPU
exception tracing separately from serial output. No real disk is attached.

## STEP 8 — VERIFY

Serial must show, in order: kernel entered; IDT loaded; triggering UD2;
`PANIC: #UD invalid opcode (vector 6)`; `RIP: 0x...`; handler reached/halting.
The script resolves expected RIP using llvm-nm, verifies the serial address,
and independently requires QEMU's trace to show vector 6 at that address.
Failure markers, normal completion, stderr, early exit, timeout and triple-fault
traces fail the test. Runs use 128/256 MiB and print two PASS lines.

Observed test-build RIP: 0xffffffff800013e2. Do not hardcode that address.
This checks fault delivery and reporting, not recovery or complete CPU liveness.

Normal regression:

```powershell
& ./scripts/build.ps1
& ./scripts/test-boot.ps1
```

## STEP 9 — DEBUG

Read the printed serial/CPU log paths. Missing IDT marker means investigate
earlier boot. Generic panic suggests gate routing. Wrong RIP suggests frame/ABI
handling. Triple fault suggests descriptor, stack, or handler faults. Reproduce
and isolate the first failure before changing unrelated code.

## STEP 10 — DOCUMENT

DOCUMENT THIS: fatal-only scope; Assembly-to-C boundary; exact saved-RIP evidence.
DO NOT BOTHER DOCUMENTING THIS: memorizing addresses or every compiler invocation.
INTERVIEW-WORTHY: CLI does not prevent UD2; exception entry differs from a C call;
returning device handlers need register preservation and interrupt return.
Questions do not block requested hands-on progress.

## STEP 11 — GIT

Commit: `Add fatal x86-64 invalid-opcode exception diagnostics`.
Earlier verified boot checkpoint e9b567c is preserved in history.

## Sources and status

- Intel SDM Volume 3A, 6.14 and #UD description:
  https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-vol-3a-part-1-manual.pdf
- UD2 documentation: https://learn.microsoft.com/en-us/cpp/intrinsics/ud2?view=msvc-170
- ABI: https://gitlab.com/x86-psABIs/x86-64-ABI/-/blob/master/x86-64-ABI/low-level-sys-info.tex

IMPLEMENTED/tested: #UD reporting and saved instruction address on QEMU.
PARTIALLY IMPLEMENTED: general exception infrastructure. UNTESTED: generic fatal
fallback, error-code exceptions, NMI and nested faults. PLANNED: device interrupts.
