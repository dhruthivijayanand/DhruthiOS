# Physical page allocator

## STEP 1 — CONCEPT
A physical page is a 4096-byte block of RAM. Allocation records that a page is in use;
freeing makes it available again. It does not erase its contents or change CPU mappings.

## STEP 2 — WHY
Without ownership records, two kernel components could use the same RAM and corrupt
each other's data. The boot memory map describes availability; this allocator tracks use.

## STEP 3 — ARCHITECTURE
Limine map -> existing validator -> page-state table -> allocate/free API.
Only the isolated pmm build includes this allocator. Normal boot and the monitor
do not yet allocate memory.

## STEP 4 — DESIGN
Each page below 1 GiB has one byte of metadata: reserved (0), free (1), allocated (2).
The table costs 256 KiB per allocator plus counters. Static kernel storage avoids
needing an allocator to create the allocator. Test instances add test-only overhead.
A bitmap would use less RAM; byte states are easier to inspect and distinguish
reserved memory from allocated memory, allowing invalid-free detection.

Only validated type-0 usable ranges enter the pool. Page zero and usable pages at
or above 1 GiB are excluded by project policy, counted in excluded. A range crossing
the cap is clipped. Kernel, firmware and bootloader data are never reclaimed.
The [Limine specification](https://github.com/limine-bootloader/limine-protocol/blob/trunk/PROTOCOL.md#memory-map-feature)
defines the map; the cap, page-zero exclusion and allocation strategy are our choices.

Allocation scans from a rotating cursor (next-fit), marks one free page allocated,
and decrements the free count. Worst case it scans 262144 entries; a known-empty
pool fails immediately. Free is constant-time and checks alignment, bounds and state.
Failed allocation leaves the output unchanged. Initialization requires zero-initialized
static storage and rejects reinitialization; an invalid map leaves it uninitialized.
An initialized empty pool is valid. Callers must not edit fields or alias output with
allocator metadata. Calls require a single execution context with interrupts disabled.
Volatile metadata stores avoid a synthesized memset dependency; volatile provides
neither locking nor protection against corrupt pointers.

## STEP 5 — CODE
- include/pmm.h: API, capacity and state storage.
- src/memory/pmm.c: validated initialization, next-fit allocation, checked free.
- tests/kernel/pmm-test.c: synthetic boundaries and actual boot-map exhaustion.
- memory_map_get(): borrowed bootloader response, never a physical-memory pointer.
- main.c/build.ps1: isolated pmm mode; test-pmm.ps1: automatic QEMU runner.

## STEP 6 — BUILD
```powershell
& ./scripts/build.ps1 -LlvmBin 'D:\Program Files\LLVM\bin' -Mode pmm
```

## STEP 7 — RUN
```powershell
& ./scripts/test-pmm.ps1 -LlvmBin 'D:\Program Files\LLVM\bin' -QemuDir 'C:\Program Files\qemu'
```
The script builds, runs and closes its own 128/256 MiB QEMU instances. Exact QEMU
arguments are in test-pmm.ps1; it uses the established UEFI/TCG isolated image.

## STEP 8 — VERIFY
Require all three PASS markers: boundary/invalid-free checks; unique usable pages
through exhaustion; all pages returned. Synthetic cases cover pre-init calls, null
arguments, malformed overlapping maps, empty pools, reinit, zero-page exclusion,
cap crossing, reserved/reclaimable frees, unaligned/out-of-range/double frees,
exhaustion and reuse. The real-map test independently computes the eligible total,
checks every allocated address against usable ranges and a separate seen table,
then frees all pages and verifies reuse. This tests ownership, not RAM contents.

## STEP 9 — DEBUG
Keep the failing build/pmm/test-*/boot-*.log. FAIL includes the failed C expression.
First distinguish a build error, pre-kernel boot error, and an allocator assertion.
Do not change firmware or memory-map policy to conceal an allocator failure.

## STEP 10 — DOCUMENT
DOCUMENT THIS: ownership transitions, metadata cost, cap and excluded pages,
exhaustion/recovery evidence, physical-address-versus-pointer distinction.
DO NOT BOTHER DOCUMENTING THIS: each loop iteration or individual returned address.
INTERVIEW-WORTHY: Why is freeing a reserved page an error? Why is an allocated
physical address not automatically safe to dereference? What would SMP require?

Limitations: no concurrency, heap, contiguous multi-page allocations, page-table
changes, ownership tokens or use-after-free prevention. A stale address can free a
later allocation at the same address; clients must obey lifetime rules. In this ownership-only suite, no RAM
content tests or physical hardware validation. Integration into the monitor is pending.

## STEP 11 — GIT
Milestone: Add checked physical page allocator and exhaustion tests.
Use only the existing local Git identity and configured remote.
Verified 2026-10-24: complete check.ps1 passed all 17 QEMU runs. Allocator logs: build/pmm/test-5508dae4de33450ab2cfeccfe5cad33e/boot-1.log and boot-2.log.

Page-content access is now tested in the separate [direct-map milestone](direct-map.md).
