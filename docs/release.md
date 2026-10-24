# Submission scope and release procedure

DhruthiOS is complete as a QEMU educational-kernel demonstration of boot, fatal
fault reporting, returning timer interrupts, physical-page ownership, memory
read/write access, and a bounded interactive monitor in Assembly, C and C++.

It is not a general-purpose operating system. No user processes, scheduler,
system calls, filesystem, network stack, general heap or kernel-owned page
tables are implemented. The serial monitor is not a physical keyboard driver.
General faults use a fatal fallback; detailed fault recovery and alternate
exception stacks remain unimplemented. Scope is explicit, not hidden by a
"fully functional OS" label.

## Five-command demonstration

Use help, about, memory, memtest and ticks. The default build remains the small
boot-and-halt baseline; demo.ps1 explicitly builds and starts monitor mode.
See demo-guide.md for exact commands and explanations.

The monitor's timer wakes its idle CPU. Memory/command services run with IF
clear, and only the waiting sequence enables IRQs. ticks counts delivered IRQ0
interrupts, not elapsed wall-clock time; long periods with IF clear may lose
individual timer events. It is not a scheduler.

## Create a verified package

Commit the reviewed source first. From PowerShell in the repository:

```powershell
& ./scripts/package.ps1 -LlvmBin 'D:\Program Files\LLVM\bin' -QemuDir 'C:\Program Files\qemu'
```

The script refuses a dirty repository, archives HEAD, and extracts a fresh
verification copy. It builds and runs the full 23-QEMU suite there. Only after
the complete success marker does it produce DhruthiOS-submission.zip under
build/releases/<timestamp>-<commit>/.

The submission contains source, documentation, vendor license/provenance,
prebuilt monitor ELF and EFI boot folder, serial/CPU test logs, RELEASE.json
with commit/tool identifiers and hashes, and SHA256SUMS.json. Source archive and
verification build remain beside it for diagnosis. No recursive cleanup or
real-machine boot installation is performed. Failed tests prevent a submission ZIP.

## Run an extracted submission

QEMU and its bundled UEFI firmware must be installed. With PowerShell opened
inside the extracted DhruthiOS folder:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
& ./scripts/verify-package.ps1
& ./scripts/run-echo.ps1 -Mode monitor -QemuDir 'C:\Program Files\qemu'
```

This uses the prebuilt kernel and needs no LLVM. To rebuild, use demo.ps1 with
your LLVM directory. To rerun every check, use check.ps1. The package script
itself requires the Git repository, whereas building/running does not.

Click QEMU and press Ctrl+Alt+2 for its serial console. Close its window to exit.
Use only QEMU for this submission; the EFI folder is not an instruction to
modify a real computer's boot partition.

## Evidence and remaining uncertainty

The archive records the exact source commit that passed its clean-build suite.
Automatic tests interact with QEMU through serial named pipes. The graphical
launch configuration is maintained alongside it, but automated testing does
not operate the graphical window. LLVM/QEMU are external prerequisites, not
included redistributables.

This is a clean-source rebuild check, not a claim that every supported machine
or tool version produces bit-for-bit identical binaries. Checksums detect
changes to packaged files; they do not authenticate the author.
