# Development log

## 2026-09-11 — Compiler target probe

Problem: the installed Clang defaults to a Windows target. The kernel needs an
explicit bare-metal target rather than ordinary Windows object files.

Decision: use `x86_64-unknown-none-elf` with freestanding C for a minimal probe.

Verification results:
- QEMU version command succeeds: 11.1.0 (v11.1.0-12130-ge470268ff4).
- Clang and LLD version commands succeed: 23.1.1.
- Clang compiled `tests/toolchain/probe.c` with exit code 0 and no diagnostics.
- `llvm-readobj --file-headers build/probe.o` succeeded and reported:
  `Format: elf64-x86-64`, `Arch: x86_64`, `AddressSize: 64bit`,
  `Type: Relocatable (0x1)`, and `Machine: EM_X86_64 (0x3E)`.

Result: compiler object-generation probe IMPLEMENTED and verified.
The function has not been executed. Kernel linking and boot remain PLANNED.
Repeat compilation produced matching ELF headers and disassembly.

Setup lesson: LLVM was installed under `D:\Program Files\LLVM`, not the example
path `D:\LLVM`. Running the executables by their verified full paths succeeded;
no reinstall was necessary.

## 2026-09-11 — ELF linker probe

Verification results: LLD linked the existing probe object with
`--entry=answer`, exited with code 0, and produced an ELF64 x86-64 executable.
The header inspector exited with code 0 and reported `Type: Executable (0x2)`.
The observed entry address was `0x201120`; this is a result of this test's
default linker layout, not a required or chosen kernel address.

Result: ELF link-format probe IMPLEMENTED and verified. It was not executed.
Repeat linking produced the same executable header and entry address.
This probe is not bootable: setting an ELF entry field does not supply a boot
protocol, a stack, a valid caller for a returning function, or kernel startup.

## 2026-09-11 — First kernel boot

Changed: added real nonreturning C kernel entry, Limine revision-6 markers,
polled COM1 output, inline architecture operations, explicit ELF layout,
boot configuration, and PowerShell build/run/test scripts. C++ is still planned.

Dependency: Limine 12.5.2 binary release; archive and loader hashes plus the
upstream license are retained in vendor/limine. No upstream signature check was
performed.

Decision: use QEMU's bundled UEFI firmware and directory-backed virtual FAT disk.
This supersedes the provisional BIOS-first recommendation and avoids requiring
a separate native Windows ISO builder. No host boot configuration was modified.

Actual failure: the first QEMU launch exited with `Block node is read-only`.
Layer: virtual disk configuration, before firmware or kernel execution.
Hypothesis: the default disk device needed a writable top-level block node.
Diagnostic/fix: retain read-only FAT backing, add snapshot=on to the disk drive
and remove top-level readonly=on for that drive. Keep firmware read-only.
Result: firmware found Limine, which loaded the unchanged kernel successfully.

Verification results:
- Compile and link exited 0 without diagnostics.
- ELF has entry 0xffffffff80001000, three PT_LOAD segments (RW, RX, R),
  each aligned to 4096 bytes. These are virtual mappings, not observed RAM placement.
- llvm-nm --undefined-only reported no undefined symbols.
- First successful serial log contains both kernel markers; QEMU stderr was empty.
- scripts/test-boot.ps1 exited 0: three fresh boots passed at 128/256/128 MiB.
- Actual scripts/run.ps1 terminal run printed both markers; Ctrl+A then X exited
  QEMU successfully with exit code 0. All test VMs were stopped.
- Tested kernel SHA-256:
  DDA7DEE63C79715AFC13EA905278529568CEA5DC055E64BAE0A9301F22C40D3F

Status: first boot and serial-output milestone IMPLEMENTED for the tested QEMU
configuration. Repeat interactive boot and three additional automated runs passed at 128/256/128 MiB.
No CPU halted-state inspection, UART failure injection, real-hardware test,
interrupt handling, heap, paging implementation, or protection boundary is claimed.

## 2026-09-17 — Fatal invalid-opcode exception milestone

Added a C IDT builder and Assembly fatal entry stubs. The #UD stub passes saved
RIP to a C diagnostic. Other gates use a generic fatal handler that is untested.
No returning interrupt handlers, exception recovery, IST or device IRQs exist yet.

The deliberate UD2 build lives under build/ud2, separate from normal boot files.
Its test compares the saved RIP against the ELF's UD2 symbol and independently
checks vector 6 and the same address in QEMU's CPU trace. It stops its own VM.

Verification results:
- C/Assembly compilation and ELF linking succeed with warnings treated as errors.
- No undefined symbols reported in either normal or exception-test ELF.
- #UD test passed at 128/256 MiB; saved RIP was 0xffffffff800013e2.
- No failure/normal-completion marker, stderr, early exit, timeout or triple fault.
- Logs: build/ud2/test-f98b4a1890b04c26ab8d22881dcf4b24.
- Updated normal build passed three boots at 128/256/128 MiB with IDT marker.
- Normal logs: build/test-7e07acc9be7a4923adedcb936bf248f9.
- Assembly disassembly confirms UD2 and the intended frame-to-C entry instructions.

General exceptions
remain PARTIALLY IMPLEMENTED; fallback, error-code exceptions, NMI and nested
faults are UNTESTED.
