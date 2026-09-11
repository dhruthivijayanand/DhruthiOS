# DhruthiOS

An educational x86-64 kernel project, developed incrementally with a four-day scope.

## Current status

Only a compiler target probe exists. There is no bootable kernel yet.
Boot, interrupts, memory allocation, and a bounded kernel shell are PLANNED.

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

## Sources

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
