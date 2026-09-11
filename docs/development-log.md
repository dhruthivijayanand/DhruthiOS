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
The learner has not yet reproduced this build or explained its result.

Setup lesson: LLVM was installed under `D:\Program Files\LLVM`, not the example
path `D:\LLVM`. Running the executables by their verified full paths succeeded;
no reinstall was necessary.

DOCUMENT THIS: host versus target, object versus executable, exact tool versions.
DO NOT BOTHER DOCUMENTING THIS: every repeated version check.
INTERVIEW-WORTHY: why a Windows-hosted compiler needs an explicit kernel target.
