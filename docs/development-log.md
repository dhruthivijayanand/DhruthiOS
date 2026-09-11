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
The learner has not yet reproduced this linking step.
This probe is not bootable: setting an ELF entry field does not supply a boot
protocol, a stack, a valid caller for a returning function, or kernel startup.

DOCUMENT THIS: linking changes the file from relocatable object to executable;
an executable format alone does not establish a valid execution environment.
DO NOT BOTHER DOCUMENTING THIS: memorizing the default entry address.
INTERVIEW-WORTHY: why ELF executable does not mean bootable operating system.
