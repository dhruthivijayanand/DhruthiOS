# DhruthiOS demonstration

## Start in VS Code's PowerShell terminal
```powershell
Set-Location 'C:\Users\DHRUTHI\Documents\DhruthiOS'
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
& .\scripts\demo.ps1 -LlvmBin 'D:\Program Files\LLVM\bin' -QemuDir 'C:\Program Files\qemu'
```
Wait for QEMU to open. Click its window and press Ctrl+Alt+2 for the serial console.
If firmware output is initially visible, allow boot to finish. Look for
'DhruthiOS monitor ready. Type help.' followed by 'DhruthiOS> '.

## Demonstrate in this order
1. help — lists the four available commands.
2. about — explains the kernel and language roles.
3. memory — displays managed, free, used and excluded usable page counts.
4. memtest — temporarily borrows two pages, tests every byte and returns them.
5. memory — verify free matches its previous value.
6. Type helx, Backspace, p, Enter — editing produces help.
7. Type an unknown command — the monitor explains how to get help.

Each page is 4096 bytes. 'used=0' means this pool has no outstanding allocations;
the kernel itself occupies separate memory that was never added to the free pool.
memtest is a small repeatable software check, not a comprehensive RAM diagnostic.
Close QEMU's window before rebuilding. No Windows disk or boot configuration is changed.

## A short honest explanation
“I built an educational x86-64 kernel that runs under QEMU. Limine loads it and
provides the initial stack, mappings and memory information. My kernel initializes
serial I/O and an interrupt table, validates the memory map, and manages physical
pages. The command monitor lets me inspect that pool and test allocated memory.
I use C for low-level services, Assembly for architecture-specific entry and I/O,
and a limited C++ component for monitor commands and bounded text formatting.
Separate tests verify invalid-opcode handling and returning timer interrupts.
There are no user processes, filesystem, network stack or kernel-owned page tables.”

Explain this in your own words; do not memorize terms you cannot explain.

## Verification
```powershell
& .\scripts\check.ps1 -LlvmBin 'D:\Program Files\LLVM\bin' -QemuDir 'C:\Program Files\qemu'
```
The complete 23-VM suite passed on 2026-10-24. Tests close their own VMs and retain
logs under build/. The integrated tests use named pipes to exercise real serial
input and output. The graphical demo wrapper was inspected but not driven by
the automated test suite.

## Interview preparation
- Boot: What did Limine do before kmain? Which parts did you implement?
- Interrupts: How is a deliberate CPU fault different from a timer interrupt?
- Memory: Why exclude kernel and bootloader ranges? Why can free RAM be less than installed RAM?
- Addressing: Why add the discovered direct-map offset instead of casting the physical address?
- Ownership: What happens if you keep using a pointer after freeing its page?
- C++: Why does this class need no heap? Which runtime features did you avoid?
- Testing: Why test two pages with different patterns and repeat commands?
- Limits: What must change before you can run isolated user programs?

## Resume wording supported by the current implementation
- Developed an educational x86-64 kernel in freestanding C, C++ and Assembly,
  booted through UEFI/Limine under QEMU on a native Windows LLVM toolchain.
- Implemented validated boot-memory discovery, checked physical-page allocation
  below 1 GiB, and allocated-page access through bootloader-provided mappings.
- Built a bounded serial command monitor and automated 23 QEMU runs covering
  boot, exceptions, timer returns, input boundaries, allocation and memory readback.

Avoid claims of production readiness, a custom bootloader, user-space isolation,
your own virtual-memory subsystem, or interrupt-driven keyboard input.
