# DhruthiOS

A small x86-64 kernel in freestanding C and Assembly, developed on Windows and
run under QEMU. The current work covers boot, fault reporting, and returning
hardware interrupts.

Normal boot loads an IDT, writes diagnostics to COM1, and halts. Separate test
images exercise an invalid-opcode exception and a PIT timer interrupt. There is
no interactive shell yet.

## Build and test

Requirements: Windows PowerShell 5.1 or newer, LLVM with Clang and LLD, and QEMU
with `share/edk2-x86_64-code.fd`. Tested with LLVM 23.1.1 and QEMU 11.1.0.
Limine 12.5.2 is included under `vendor/limine`.

From the repository root:

```powershell
./scripts/check.ps1
```

This builds the kernel and runs eight QEMU cases: three normal boots, two fault
checks, two timer-return checks, and one masked-timer control. Each VM closes
automatically. Logs are saved under `build/`.

Scripts look for tools on `PATH` and in the standard installation directories.
For a custom installation, set the directories in the current PowerShell session:

```powershell
$env:LLVM_BIN = 'D:\Program Files\LLVM\bin'
$env:QEMU_DIR = 'C:\Program Files\qemu'
./scripts/check.ps1
```

If Windows blocks local scripts, run the following in that terminal, then retry.
The setting ends when the terminal closes.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
```

To build and run normal boot separately:

```powershell
./scripts/build.ps1
./scripts/run.ps1
```

Expected kernel output:

```text
DhruthiOS: kernel entered
DhruthiOS: IDT loaded
DhruthiOS: boot protocol accepted; CPU halted
```

The interactive runner uses QEMU's terminal console. Press Ctrl+A, release both
keys, then press X to exit. If the terminal does not pass that sequence through,
close that QEMU process in Task Manager. Stop the VM before rebuilding: its
virtual disk reads the files in `build/esp`.

## What is implemented

| Component | Status | Evidence |
| --- | --- | --- |
| UEFI/Limine boot and serial output | IMPLEMENTED | Repeated boots at 128 and 256 MiB |
| Fatal invalid-opcode handler | IMPLEMENTED | Saved RIP matches the fault symbol and QEMU trace |
| PIT/PIC timer interrupt | IMPLEMENTED in test images | Repeated returns, register/flag checks, masked-IRQ control |
| General exception handling | PARTIALLY IMPLEMENTED | IDT installed; generic fatal fallback is UNTESTED |
| Physical memory allocator and kernel shell | PLANNED | No implementation yet |
| User space, scheduling, filesystem, networking | FUTURE WORK | Outside the current kernel |

## Design

```text
QEMU PC / UEFI
       |
     Limine -- loads ELF, supplies stack and initial page tables
       |
     kmain -- checks protocol revision, initializes serial output and IDT
       |
       +-- normal image: halt
       +-- fault image: UD2 -> vector 6 -> fatal diagnostic
       +-- timer image: PIT -> PIC -> vector 32 -> tick count -> IRETQ
```

The kernel runs on one virtual CPU. C owns initialization and device state;
Assembly handles port I/O and interrupt entry/return. It uses Limine's memory
mappings and has no allocator or user/kernel isolation. There is no C++ runtime
or C++ component at this stage.

 [Architecture](docs/architecture.md): source layout and kernel contracts.
 [Boot](docs/boot-process.md): handoff, ELF layout, and serial output.
 [Exceptions](docs/interrupts.md) and [timer](docs/timer.md): entry paths and limits.
 [Testing](docs/testing.md): commands, assertions, and failure diagnosis.
 [Development log](docs/development-log.md): results and problems encountered.
 [Boot decision](docs/technical-decisions/0001-uefi-limine.md): why UEFI and Limine.

Validation is limited to QEMU's PC model with TCG. There is no real-hardware
support claim, bootable ISO, or installer. The next substantial task is reading
the boot memory map and implementing a physical page allocator.

## Dependencies

[Limine](https://github.com/limine-bootloader/limine) provides the bootloader.
Its BSD-2-Clause license and recorded binary hashes are retained in
[vendor/limine](vendor/limine/PROVENANCE.md).
