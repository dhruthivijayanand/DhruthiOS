# Accessing allocated pages

## STEP 1 — CONCEPT
The allocator records ownership of physical RAM. A C pointer is a virtual address:
the CPU uses existing page tables to translate it. A direct map gives an address
for a mapped physical location by adding a discovered offset.

## STEP 2 — WHY
Kernel components need to store data in their allocated pages. Casting a physical
address straight to a pointer would assume an identity mapping we do not have.

## STEP 3 — ARCHITECTURE
Limine creates mappings -> HHDM response supplies offset -> allocator supplies
owned page -> checked addition supplies pointer -> byte stores and loads.
This milestone uses the existing page tables; it does not implement new ones.

## STEP 4 — DESIGN
Protocol facts verified on 2026-10-24:
- Limine's HHDM response provides the offset; it must not be hardcoded.
- Usable regions are mapped under our requested base revision 6.
- Bootloader page tables remain in bootloader-reclaimable memory.

Sources: [protocol](https://github.com/limine-bootloader/limine-protocol/blob/trunk/PROTOCOL.md#hhdm-higher-half-direct-map-feature)
and [wire definitions](https://github.com/limine-bootloader/limine-protocol/blob/trunk/include/limine.h).

Our policy: accept response revision 0, require a nonzero page-aligned offset,
page-aligned physical address below the allocator's 1 GiB cap, and addition that
does not overflow through the page's last byte. Reject null arguments; leave
arithmetic output unchanged on error. Higher response revisions are rejected
conservatively, not because the protocol promises incompatibility.

The arithmetic helper does NOT verify page-table entries or canonical addresses.
The pointer helper additionally requires current allocation in a pool initialized
from the actual boot map. It trusts the bootloader's response and mappings.
Arbitrary response pointers or fabricated pools are outside this contract.
No bootloader data or page tables are freed.

A returned pointer is borrowed: callers must stop using it before freeing the page.
Freeing changes ownership metadata; it does not unmap the page or invalidate old
pointers in the CPU. These checks are kernel programming guards, not isolation.
Single caller with interrupts disabled remains required.

## STEP 5 — CODE
- include/direct_map.h: response layout, arithmetic helper, borrowed page-pointer API.
- src/memory/direct_map.c: HHDM request, layout assertions and checked conversion.
- pmm_is_allocated(): read-only ownership query with alignment and range guards.
- tests/kernel/direct-map-test.c: synthetic address checks and actual page access.
- build/main: isolated directmap mode; scripts/test-directmap.ps1: automated runner.

## STEP 6 — BUILD
```powershell
& ./scripts/build.ps1 -LlvmBin 'D:\Program Files\LLVM\bin' -Mode directmap
```

## STEP 7 — RUN
```powershell
& ./scripts/test-directmap.ps1 -LlvmBin 'D:\Program Files\LLVM\bin' -QemuDir 'C:\Program Files\qemu'
```
The script rebuilds, boots at 128/256 MiB, captures serial logs, and closes only
its own QEMU processes. Exact QEMU arguments are recorded in the script.

## STEP 8 — VERIFY
Require arithmetic, distinct byte patterns, and returned-pages PASS markers.
Synthetic checks cover missing arguments, unsupported revision, missing/unaligned
offset, arithmetic overflow, misaligned/out-of-range physical addresses, and
valid boundary sums. Example offsets are never dereferenced.

The actual-memory test allocates two distinct pages, writes different index-based
patterns to every byte, then reads every byte back. A second pass reverses the
patterns. Writes precede verification of both pages so accidental aliasing is
detectable. Volatile loads/stores prevent the compiler replacing the readback
with a known value; they do not flush caches or create synchronization.

The test also checks null/uninitialized pools, zero/unaligned/out-of-range pages,
and refusal to issue a new pointer after free. Both pages return to the pool and
the free count matches the initial count. The old pointers are never used again.

## STEP 9 — DEBUG
A FAIL marker includes the failed expression. A fault during memory access calls
the existing generic fatal handler; detailed page-fault decoding is future work.
Preserve the serial log before changing anything. First check boot response,
ownership, address arithmetic and build mode. Do not alter arbitrary page tables.

## STEP 10 — DOCUMENT
DOCUMENT THIS: allocation versus mapping; discovered offset; two-page pattern
test; pointer lifetime; trust in bootloader mappings.
DO NOT BOTHER DOCUMENTING THIS: every byte value or every build command repetition.
INTERVIEW-WORTHY: Why does freeing a page not stop an old pointer from writing?
Why test two pages with different patterns? Why is this not virtual-memory management?

Limitations: two allocated pages per QEMU boot, not all RAM; no cache/DRAM fault
testing, no own page tables, no user isolation, no pointer revocation, no SMP.
Normal and interactive images do not yet use the allocator or this pointer helper.

## STEP 11 — GIT
Milestone: Verify allocated page access through the bootloader direct map.

Verified 2026-10-24: check.ps1 passed all 19 QEMU runs. Direct-map logs:
build/directmap/test-7c2fe0d48acd4fbfa9c11ff745eede9b/boot-1.log and boot-2.log.

Integration update: the monitor image now uses these services through memory and
memtest commands. Earlier isolation statements describe this milestone's original
test image; normal and legacy echo remain unchanged. See [monitor.md](monitor.md).
