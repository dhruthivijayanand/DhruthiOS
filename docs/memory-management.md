# Boot memory map — read-only milestone

## STEP 1 — CONCEPT

Installed RAM is not the same as available RAM. Some memory holds the kernel,
bootloader data, page tables or firmware. A memory map describes address ranges
with a starting address, byte count, and purpose. A physical address identifies
a location in the machine's physical address space; it is not automatically
a C pointer that the current virtual-memory mappings let us dereference.

## STEP 2 — WHY

An allocator must choose available memory without overwriting existing state.
This milestone inspects the map; it does not allocate, clear, free or probe RAM.

## STEP 3 — ARCHITECTURE

UEFI -> Limine -> memory-map response -> validator -> serial report.
Only the isolated memmap image includes the new request and reader.
Normal, echo, command and interrupt test modes retain their behaviour.

## STEP 4 — DESIGN

The revision-0 request/response layouts and numeric IDs follow the
[Limine protocol](https://github.com/limine-bootloader/limine-protocol/blob/trunk/PROTOCOL.md#memory-map-feature)
and its [C header](https://github.com/limine-bootloader/limine-protocol/blob/trunk/include/limine.h),
checked on 2026-10-24. The project still requests base revision 6.
Compile-time size and offset assertions check the x86-64 structure layout.

Response pointers already include the direct-map offset; region bases remain
physical numbers. We read the response structures, never dereference the region
bases. Only type 0 (usable) contributes to available bytes and 4096-byte pages.
Bootloader-reclaimable memory remains excluded because it can contain live data.
Unknown types remain nonusable. Usable and bootloader-reclaimable regions must
be aligned and cannot overlap any other entry; other region types may overlap.

Project policies: at most 1024 entries, response revision exactly 0, no zero-length
entries, no overflowing base+length, sorted bases. The protocol is trusted to
supply readable pointers: these checks do not make arbitrary pointers safe.
The validator is quadratic in entry count, bounded by our cap. It publishes
totals only after all entries pass and zeros its output on validation failure.
These are conservative policies, not universal firmware requirements.

## STEP 5 — CODE

- include/memory_map.h: wire layouts, summary and interfaces.
- src/memory/memory_map.c: request, validation and decimal/hex serial report.
- tests/kernel/memory-map-test.c: 20 deterministic checks using synthetic maps.
- main.c: isolated test/report entry; build.ps1: memmap mode.
- scripts/test-memmap.ps1: QEMU boots, parsed ranges and independent totals.

## STEP 6 — BUILD

```powershell
& ./scripts/build.ps1 -LlvmBin 'D:\Program Files\LLVM\bin' -Mode memmap
```

## STEP 7 — RUN

```powershell
& ./scripts/test-memmap.ps1 -LlvmBin 'D:\Program Files\LLVM\bin'
```

The script builds, runs and closes three VMs automatically. It uses the same
UEFI/TCG configuration and temporary virtual disk as the existing tests.
Only virtual-machine memory is described, never the host laptop's physical RAM.

## STEP 8 — VERIFY

All three runs passed on 2026-10-24; every run also passed 20 validator checks.

| QEMU RAM | Reported usable bytes |
| --- | --- |
| 128 MiB | 82,255,872 |
| 256 MiB | 216,473,600 |
| 512 MiB | 484,909,056 |

These are observations, not hardcoded expected addresses or totals.
Logs: build/memmap/test-a432b70ceff446db9cdb7ef74fdcc5fa/.
The runner sums usable lengths from MAP lines and checks reported bytes/pages,
entry count, plausible RAM bounds, and increasing usable RAM across sizes.
All 12 existing regression VM runs also passed during this milestone.
The combined check.ps1 now schedules 15 VM runs; its constituent suites were
validated as 12 existing runs plus 3 separate memory-map runs.

Synthetic checks include missing pointers, revision/count errors, zero lengths,
overflow, sorting, overlap, alignment, excluding reclaimable/unknown types,
accepting permitted reserved overlaps, and a usable range beginning at zero.

## STEP 9 — DEBUG

A 64 MiB attempt failed inside Limine's allocator before kernel entry.
The preserved log is build/memmap/test-0fd0230e99ea453b9325efb15a331080/.
128/256/512 MiB passed. Do not claim 64 MiB support for this boot environment.
The tests folder was missing at the start of the milestone and was restored
from the latest local Git commit with the user's explicit approval.

## STEP 10 — DOCUMENT

DOCUMENT THIS: physical numbers versus virtual pointers; why only usable ranges
count; independent totals; the pre-kernel low-memory failure.
DO NOT BOTHER DOCUMENTING THIS: every build invocation or incidental address.
INTERVIEW-WORTHY: why reclaimable does not mean immediately free; why valid
reserved overlaps differ from usable-memory overlaps; how allocation will
require ownership tracking, beyond inspecting this map.

Status: read-only memory-map discovery IMPLEMENTED in the tested QEMU images.
Allocation and freeing are now implemented in the separate [physical-page milestone](physical-pages.md). Page-table ownership and heap management remain PLANNED.
No real-hardware, corrupted-pointer recovery or >1024-entry support claimed.

## STEP 11 — GIT

Milestone commit: Add validated boot memory map and QEMU tests.
Use the existing configured identity and remote; no identity changes.
