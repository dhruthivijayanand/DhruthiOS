# 0001: UEFI boot with Limine

Status: accepted.

## Context

The development host is Windows with native LLVM and QEMU. QEMU includes x86-64
UEFI firmware. A separate ISO-building toolchain would add another dependency
before any kernel code could run.

## Decision

Use Limine 12.5.2 with QEMU's UEFI firmware and a directory-backed virtual FAT
disk. Give the drive a temporary snapshot layer. Keep the loader binary, license,
and measured hashes in the repository.

## Alternatives

A BIOS ISO would require a different packaging path. A custom loader would make
firmware interfaces and mode transitions prerequisites for kernel work. Both are
valid future projects; neither is needed for the current interrupt and memory
management work.

## Consequences

The kernel owns its ELF layout, revision check, diagnostics, and interrupt
handling. Limine owns loading and initial CPU, stack, and page-table setup.
The output is a QEMU boot directory, not an ISO or installer. Rebuilding requires
stopping any VM using that directory. BIOS and real hardware are not supported
by the current test configuration.
