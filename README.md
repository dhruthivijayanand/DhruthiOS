# DhruthiOS

A small educational x86-64 kernel in freestanding C and Assembly, developed
on Windows and run under QEMU. It demonstrates boot, fault reporting, returning
hardware interrupts, and an interactive serial command interface.

Normal boot prints diagnostics and halts. Separate images exercise exceptions,
timer interrupts, commands, and the interactive monitor. It is not a production
OS: no allocator, user processes, filesystem, networking, or C++ component yet.

## Build, test, demonstrate

Requirements: Windows PowerShell 5.1 or newer, LLVM Clang/LLD and QEMU with
`share/edk2-x86_64-code.fd`. Tested tools: LLVM 23.1.1, QEMU 11.1.0.
Limine 12.5.2 is included in vendor/limine.

From the repository folder, allow local scripts for this terminal session if
needed, and configure your installed tool directories:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
$env:LLVM_BIN = 'D:\Program Files\LLVM\bin'
$env:QEMU_DIR = 'C:\Program Files\qemu'
& ./scripts/check.ps1
```

The check script runs 15 QEMU instances: 3 normal boots, 2 exception tests,
2 timer returns, 1 masked-timer control, 2 command-test boots (17 cases each),
2 serial integration runs (14 scenarios each), and 3 memory-map runs (20 validator cases each). VMs close automatically;
logs stay in build/. The existing eight regressions and both new test suites
passed on 2026-10-24. The memory-map suite also passed at 128/256/512 MiB.

To demonstrate the interactive monitor:

```powershell
& ./scripts/build.ps1 -Mode echo
& ./scripts/run-echo.ps1
```

In the QEMU window press **Ctrl+Alt+2** for serial output. Type `help` or
`about`, then Enter. Backspace edits input. Close the window to exit.
Stop QEMU before rebuilding its image. The monitor accepts up to 31 printable
characters and rejects an oversized line until Enter, then offers a fresh prompt.
It actively polls and does not support arrows, escape sequences, or Unicode.

Normal boot is still available with build.ps1 (default mode) and run.ps1.
The normal runner uses the terminal: Ctrl+A then X requests exit, but some
Windows terminals do not pass this sequence through; close that QEMU process
in Task Manager if necessary.

## Status

| Component | Status | Evidence |
| --- | --- | --- |
| UEFI/Limine boot and serial output | IMPLEMENTED | Repeated 128/256 MiB boots |
| Fatal invalid-opcode handler | IMPLEMENTED | Saved RIP and QEMU fault trace agree |
| PIT/PIC returning timer interrupt | IMPLEMENTED in test images | Registers/flags, tick count, masked control |
| General exceptions | PARTIALLY IMPLEMENTED | Generic fallback and nested faults remain UNTESTED |
| Command selection | IMPLEMENTED | 17 automated cases per memory size |
| Serial kernel monitor | PROTOTYPE | 14 automated serial scenarios per memory size |
| Read-only boot memory map | IMPLEMENTED in memmap image | 20 validator cases and independent totals at 128/256/512 MiB |
| Memory allocator and limited C++ | PLANNED | Not implemented |
| User space, scheduling, filesystem, networking | FUTURE WORK | Not implemented |

## Architecture

```text
QEMU PC / UEFI -> Limine -> kmain
                             |
                             +-- normal: initialize serial and IDT, halt
                             +-- ud2: vector 6 -> fatal diagnostic
                             +-- timer: PIT -> PIC -> vector 32 -> IRETQ
                             +-- echo: serial bytes -> bounded line
                                              -> command_response -> serial output
```

The kernel uses one virtual CPU and Limine's initial stack and page tables.
C owns device state and command logic; Assembly handles port I/O and interrupt
entry/return. The command interface executes inside the kernel, not in isolated
user space. No hosted runtime or dynamic allocation is used.

## Documentation

- [Architecture](docs/architecture.md) and [boot](docs/boot-process.md).
- [Exceptions](docs/interrupts.md) and [timer](docs/timer.md).
- [Command contracts, demo and automated evidence](docs/commands.md).
- [Existing regression tests](docs/testing.md).
- [Memory map and allocation roadmap](docs/memory-management.md).
- [Development log](docs/development-log.md).
- [UEFI/Limine decision](docs/technical-decisions/0001-uefi-limine.md).

Validation is limited to QEMU's PC model with TCG. There is no real-hardware
support claim, installer, bootable ISO, or production reliability claim.
Next: use the validated boot memory map to implement a physical page allocator.

## Dependencies

[Limine](https://github.com/limine-bootloader/limine) supplies the bootloader.
Its BSD-2-Clause license and recorded binary hashes remain in
[vendor/limine](vendor/limine/PROVENANCE.md).
