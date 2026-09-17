# DhruthiOS

An educational x86-64 kernel project, developed incrementally with a four-day scope.

## Current status

IMPLEMENTED and tested in QEMU: UEFI/Limine boot, freestanding C entry with
inline x86-64 Assembly, boot-revision check, polled serial output and fatal #UD
reporting with a verified instruction address. General exception infrastructure
is PARTIALLY IMPLEMENTED; other vectors use an UNTESTED generic fatal fallback.
Device interrupts, memory allocation, and a bounded kernel shell are PLANNED.
There is no user space, scheduler, filesystem, networking, or meaningful C++
component yet. Normal boot installs an IDT, prints status and enters a halt loop.

## Build and run the kernel

From this repository directory in PowerShell:

```powershell
& ./scripts/build.ps1
& ./scripts/run.ps1
```

Expected terminal output after firmware messages:

```text
DhruthiOS: kernel entered
DhruthiOS: IDT loaded
DhruthiOS: boot protocol accepted; CPU halted
```

Quit QEMU with Ctrl+A, release, then X. Stop QEMU before rebuilding.
The run script uses one CPU, 128 MiB RAM, TCG emulation, bundled UEFI firmware,
and a project-directory virtual FAT disk with temporary guest writes.

Verified tools: Clang/LLD 23.1.1 at `D:\Program Files\LLVM\bin`, QEMU 11.1.0 at
`C:\Program Files\qemu`, Limine 12.5.2 included with its upstream license in
vendor/limine. Build/run scripts accept alternate tool directories as parameters.

Architecture: QEMU PC -> UEFI firmware -> Limine -> C kmain -> serial output.
The kernel uses Limine's initial stack and page tables; we did not implement
those mechanisms or a bootloader. The serial device is polled with bounded
attempts; there is no interrupt-based output or exception recovery yet.

Read [the boot milestone walkthrough](docs/boot-process.md) for all eleven steps,
source explanations, exact commands, debugging evidence, and references.

## Verification

Run the exception test (builds a separate test image and closes QEMU automatically):

```powershell
& ./scripts/test-exception.ps1
```

Expected: two PASS lines confirming #UD and its fault address, at 128/256 MiB RAM.
The script checks QEMU's exception trace as well as kernel serial output.
See [the exception walkthrough](docs/interrupts.md) for source and all eleven steps.

Rebuild and test normal boot:

```powershell
& ./scripts/build.ps1
& ./scripts/test-boot.ps1
```

Three fresh boots passed with 128, 256, and 128 MiB RAM. The interactive run script
also printed the two markers and exited successfully with Ctrl+A then X. ELF
inspection at the first boot milestone showed entry 0xffffffff80001000, separate
RW/RX/R loadable segments, and no unresolved symbols. See docs/development-log.md.

Limitations: emulator-only testing; no real-hardware validation, negative UART
tests, comprehensive fault recovery, memory isolation, or independent halted-state measurement.
The current image is a directory-backed QEMU boot setup, not a standalone ISO.
Future milestones: extend exception diagnostics and add timer interrupts, then
physical memory allocation and the bounded shell.

## First exercise: compile a C function

`tests/toolchain/probe.c` defines a function named `answer`. It takes no arguments
and returns the integer 42. It does not print anything. It is not a kernel entry
point and must not be booted or launched as a Windows program.

From this repository's directory, run in PowerShell:

```powershell
New-Item -ItemType Directory -Force build | Out-Null
& 'D:\Program Files\LLVM\bin\clang.exe' --target=x86_64-unknown-none-elf -ffreestanding -std=c11 -Wall -Wextra -Werror -c tests/toolchain/probe.c -o build/probe.o
& 'D:\Program Files\LLVM\bin\llvm-readobj.exe' --file-headers build/probe.o
```

The compiler should exit successfully. The inspector should report
`Format: elf64-x86-64`, `Arch: x86_64`, and `Type: Relocatable`.

- `--target`: explicitly chooses the target instead of the compiler's Windows default.
- `-ffreestanding`: selects freestanding language assumptions.
- `-std=c11`: selects the C11 language standard.
- `-Wall -Wextra -Werror`: enables common/additional warnings and treats warnings as errors.
- `-c`: stops after creating an object file; no linking occurs.
- `-o`: names the output file.

These are probe flags, not the complete future kernel build configuration.
This check verifies object generation and its target format, not execution,
linking, bootability, or complete kernel toolchain readiness.

## Second exercise: verify ELF linking

From the same repository directory in PowerShell:

```powershell
& 'D:\Program Files\LLVM\bin\ld.lld.exe' --entry=answer -o build/link-probe.elf build/probe.o
& 'D:\Program Files\LLVM\bin\llvm-readobj.exe' --file-headers build/link-probe.elf
```

Expected: `Format: elf64-x86-64` and `Type: Executable (0x2)`.
`--entry=answer` sets the ELF entry address to the address of that symbol.
This is only a linker-format probe. It has no boot-protocol integration or
startup environment. Its function returns and needs a valid caller. Do not
execute or boot this file. Its default linker layout is not our kernel layout.
The future kernel needs a deliberate entry routine, layout, and boot contract.

## References

- [Clang cross-compilation](https://clang.llvm.org/docs/CrossCompilation.html)
- [Clang freestanding builds](https://clang.llvm.org/docs/UsersManual.html#freestanding-builds)
