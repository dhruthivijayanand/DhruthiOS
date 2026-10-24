# Interactive memory monitor and limited C++

## STEP 1 — CONCEPT
A command monitor reads a line, recognizes a command, calls the relevant kernel
service, prints a result and waits for another line. It is not a separate process.
Here the existing C input loop calls a C++ command service, which calls C memory APIs.

## STEP 2 — WHY
Separate test images prove mechanisms. An integrated monitor makes those mechanisms
demonstrable: memory reports ownership counts; memtest borrows two pages, checks
their contents and returns them without a reboot.

## STEP 3 — ARCHITECTURE
Serial device -> C bounded line editor -> C++ monitor_execute -> C allocator/direct
map -> RAM -> C++ fixed-size report -> C serial driver.
Assembly still serves interrupt entry/return and architecture-specific instructions.
Normal and legacy echo builds remain available.

## STEP 4 — DESIGN
Commands: help, about, memory, memtest, ticks. Exact lengths and bytes must match;
memoryx and memtestx are unknown commands. The line limit remains 31 printable bytes.
The monitor owns one static allocator initialized from the real Limine memory map.

memory prints counts in 4096-byte pages:
- managed: usable pages included in our pool.
- free: managed pages currently available.
- used: managed minus free, not all memory occupied by firmware or the kernel.
- excluded: otherwise usable pages omitted by the 1 GiB cap or page-zero policy.
Reserved/kernel/bootloader regions never enter managed or excluded-usable totals.

memtest acquires two pages, writes distinct full-page patterns twice, reads them
back, and releases all acquired pages. A partial allocation releases what succeeded.
It checks that the free count returns to its original value. Corruption or cleanup
failure prints a panic and returns failure to the caller, which halts.
Insufficient pages produces an unavailable message. These error branches have
been inspected but not fault-injected in the interactive integration suite.

### What our C++ subset means
Hosted C++ normally comes with an operating system and runtime library. Here Clang
compiles freestanding C++17 into the same ELF kernel as our C and Assembly.
The monitor's TextBuffer template bundles its fixed array, length and failure flag.
Its methods prevent writing past capacity and refuse to publish a partial report.
A template chooses the capacity at compile time; it does not allocate memory.

The constructor runs normally when the local report object is created on the stack.
No global object requires runtime construction; the allocator is statically zeroed.
No custom destructors or exit handlers exist. No new/delete, standard containers,
exceptions, virtual dispatch, RTTI or standard C++ library are used.
Exceptions would need unwinding support; RTTI supplies runtime type information.
We disable them because this component needs neither. extern C gives exported
functions and imported C services the C language linkage expected by the linker.

Flags: -std=c++17, -ffreestanding, -fno-exceptions, -fno-rtti, -nostdinc++.
-Wglobal-constructors and -Wexit-time-destructors join the existing -Werror policy.
The linker uses no hosted libraries and rejects unresolved runtime references.
This is a deliberately limited subset, not a complete freestanding library.
Clang may generate memory-library calls for other code; future code that needs
them must provide correct implementations rather than bypass the link check.
See [Clang manual](https://clang.llvm.org/docs/UsersManual.html#freestanding-builds)
and [flag reference](https://clang.llvm.org/docs/ClangCommandLineReference.html).

## STEP 5 — CODE
- include/text_buffer.hpp: bounded template with checked append and decimal formatting.
- include/monitor.h and src/kernel/monitor.cpp: C interface and C++ command service.
- main.c: existing line loop shared between echo and monitor modes.
- build.ps1: source-specific C/C++ flags; isolated monitor and format builds.
- tests/kernel/format-test.cpp: exact capacity, overflow, null input, zero, UINT64_MAX.
- test-echo.ps1 -Mode monitor: serial interaction and repeated memory operations.
- demo.ps1: builds and opens the integrated demo with the existing graphical runner.

## STEP 6 — BUILD
```powershell
& ./scripts/build.ps1 -LlvmBin 'D:\Program Files\LLVM\bin' -Mode monitor
```

## STEP 7 — RUN
One-command build and launch:
```powershell
& ./scripts/demo.ps1 -LlvmBin 'D:\Program Files\LLVM\bin' -QemuDir 'C:\Program Files\qemu'
```
In QEMU press Ctrl+Alt+2 for the serial console. Type help, about, memory, memtest,
then memory again. The free count should be unchanged. Close the QEMU window to exit.
Stop the demo before rebuilding its virtual disk.

## STEP 8 — VERIFY
test-echo.ps1 -Mode monitor runs the same 14 editing/command scenarios as echo,
plus an initial parsed memory report, two invalid suffix commands and ten cycles
of memtest followed by an exact comparison with the original memory report.
It runs at both 128 and 256 MiB. test-format.ps1 validates formatter boundaries
in separate kernel boots at both sizes. check.ps1 now runs 23 VMs.
Generated monitor ELF has no unresolved symbols or constructor/destructor arrays.

## STEP 9 — DEBUG
During integration a broad edit inserted an extra #endif at the overflow reset.
Clang rejected main.c before linking. Inspection located the unrelated insertion;
removing just that marker fixed compilation. The original line-handling logic
was retained and is covered by serial regressions.
llvm-readelf was absent in this LLVM install; llvm-readobj provided section inspection.
Preserve build/monitor/test-*/serial-*.log for command errors.

## STEP 10 — DOCUMENT
DOCUMENT THIS: language boundaries, fixed-storage C++, count meanings, cleanup
and repeated tests. DO NOT BOTHER DOCUMENTING THIS: every intermediate build.
INTERVIEW-WORTHY: Why can C++ run without an OS? What does the constructor need?
Why does used=0 not mean the kernel occupies no RAM? How would a page leak appear?

Limitations: kernel privilege only, polling input, one CPU, interrupts disabled during command execution, no processes, heap, filesystem, networking or own page
tables. The final monitor also enables timer interrupts while waiting for serial input. The graphical
launch wrapper uses the previously supported SDL/serial interface; this milestone's
automated interaction uses named pipes rather than driving the graphical window.

## STEP 11 — GIT
Milestone: Add C++ memory monitor and integrated demo.

Verified 2026-10-24: all 23 QEMU runs passed. Monitor evidence:
build/monitor/test-40c092a68cad4149ad8b4bfaca3d95f6/serial-{128M,256M}.log.
Formatter evidence: build/format/test-c71b7e8e176d4f79bbf5b820938c48cf/.


## Final integration: timer-driven idle waiting

After initializing the allocator, the monitor calls timer_init. When no serial
byte is available it executes STI; HLT; CLI in one inline Assembly statement.
It enters with IF clear, waits with IRQ0 enabled, then restores IF-clear service
contracts. The timer handler only updates ticks and acknowledges the PIC.
Only IRQ0 is unmasked; HPET is disabled in this QEMU configuration.

ticks reports delivered interrupts, not uptime. Serial input is still polled,
roughly on timer wakeups, not interrupt-driven UART input. Command execution
can delay/miss individual timer events; no timekeeping accuracy is claimed.

The integration test requires nonzero/increasing counts while idle and continued
delivery after ten memory-test cycles. Existing input-boundary checks run too.
See Intel SDM Volume 2B, STI, for delayed recognition after STI:
https://www.intel.com/content/dam/www/public/us/en/documents/manuals/64-ia-32-architectures-software-developer-vol-2b-manual.pdf
