# Development log

## 2026-09-11 — Compiler target probe

Problem: the installed Clang defaults to a Windows target. The kernel needs an
explicit bare-metal target rather than ordinary Windows object files.

Decision: use `x86_64-unknown-none-elf` with freestanding C for a minimal probe.

Verified by the assistant on this machine:
- QEMU version command succeeds: 11.1.0 (v11.1.0-12130-ge470268ff4).
- Clang and LLD version commands succeed: 23.1.1.
- Clang compiled `tests/toolchain/probe.c` with exit code 0 and no diagnostics.
- `llvm-readobj --file-headers build/probe.o` succeeded and reported:
  `Format: elf64-x86-64`, `Arch: x86_64`, `AddressSize: 64bit`,
  `Type: Relocatable (0x1)`, and `Machine: EM_X86_64 (0x3E)`.

Result: compiler object-generation probe IMPLEMENTED and verified.
The function has not been executed. Kernel linking and boot remain PLANNED.
The learner subsequently reproduced object generation and supplied matching ELF
headers and disassembly. We discussed how `return 42;` places 42 in EAX and
returns to the caller without printing anything.

Setup lesson: LLVM was installed under `D:\Program Files\LLVM`, not the example
path `D:\LLVM`. Running the executables by their verified full paths succeeded;
no reinstall was necessary.

DOCUMENT THIS: host versus target, object versus executable, exact tool versions.
DO NOT BOTHER DOCUMENTING THIS: every repeated version check.
INTERVIEW-WORTHY: why a Windows-hosted compiler needs an explicit kernel target.

## 2026-09-11 — ELF linker probe

Verified by the assistant: LLD linked the existing probe object with
`--entry=answer`, exited with code 0, and produced an ELF64 x86-64 executable.
The header inspector exited with code 0 and reported `Type: Executable (0x2)`.
The observed entry address was `0x201120`; this is a result of this test's
default linker layout, not a required or chosen kernel address.

Result: ELF link-format probe IMPLEMENTED and verified. It was not executed.
The learner reproduced this linking step and supplied the matching executable
header and entry address.
This probe is not bootable: setting an ELF entry field does not supply a boot
protocol, a stack, a valid caller for a returning function, or kernel startup.

DOCUMENT THIS: linking changes the file from relocatable object to executable;
an executable format alone does not establish a valid execution environment.
DO NOT BOTHER DOCUMENTING THIS: memorizing the default entry address.
INTERVIEW-WORTHY: why ELF executable does not mean bootable operating system.

## 2026-09-11 — First kernel boot

Changed: added real nonreturning C kernel entry, Limine revision-6 markers,
polled COM1 output, inline architecture operations, explicit ELF layout,
boot configuration, and PowerShell build/run/test scripts. C++ is still planned.

Dependency: user downloaded Limine 12.5.2; archive and loader hashes plus the
upstream license are retained in vendor/limine. No upstream signature check was
performed. Native network download was blocked, so the user supplied the archive.

Decision: use QEMU's bundled UEFI firmware and directory-backed virtual FAT disk.
This supersedes the provisional BIOS-first recommendation and avoids requiring
a separate native Windows ISO builder. No host boot configuration was modified.

Actual failure: the first QEMU launch exited with `Block node is read-only`.
Layer: virtual disk configuration, before firmware or kernel execution.
Hypothesis: the default disk device needed a writable top-level block node.
Diagnostic/fix: retain read-only FAT backing, add snapshot=on to the disk drive
and remove top-level readonly=on for that drive. Keep firmware read-only.
Result: firmware found Limine, which loaded the unchanged kernel successfully.

Verified by the assistant:
- Compile and link exited 0 without diagnostics.
- ELF has entry 0xffffffff80001000, three PT_LOAD segments (RW, RX, R),
  each aligned to 4096 bytes. These are virtual mappings, not observed RAM placement.
- llvm-nm --undefined-only reported no undefined symbols.
- First successful serial log contains both kernel markers; QEMU stderr was empty.
- scripts/test-boot.ps1 exited 0: three fresh boots passed at 128/256/128 MiB.
- Actual scripts/run.ps1 terminal run printed both markers; Ctrl+A then X exited
  QEMU successfully with exit code 0. All assistant-started test VMs were stopped.
- Tested kernel SHA-256:
  DDA7DEE63C79715AFC13EA905278529568CEA5DC055E64BAE0A9301F22C40D3F

Status: first boot and serial-output milestone IMPLEMENTED for the tested QEMU
configuration. The user subsequently reproduced the interactive boot and supplied
three passing automated runs at 128/256/128 MiB. A source walkthrough has begun.
No CPU halted-state inspection, UART failure injection, real-hardware test,
interrupt handling, heap, paging implementation, or protection boundary is claimed.

DOCUMENT THIS: boot contract, actual root-cause fix, explicit scope and evidence.
DO NOT BOTHER DOCUMENTING THIS: every duplicate successful run or protocol number.
INTERVIEW-WORTHY: why return is invalid at kernel entry; which work Limine performs.

## 2026-09-17 — Resume and GitHub preparation

Resumed at e9b567c with a clean working tree. One fresh 128 MiB automated boot
passed and the test stopped QEMU. No exception-handler code has been added yet.

User-side setup lessons from the prior session: Windows PowerShell initially
blocked local scripts; session-scoped RemoteSigned was suggested and the user
then successfully built and booted. Interactive QEMU exit shortcuts did not work
in the user's terminal; the user ended QEMU through Task Manager. Prefer bounded
tests that stop their own VM while this terminal behavior remains unresolved.

The user requested GitHub setup and ongoing milestone uploads. Saved that workflow
in AGENTS.md and docs/github.md. Remote creation and upload are pending; available
connector tools cannot create a repository, and local credential lookup failed.
