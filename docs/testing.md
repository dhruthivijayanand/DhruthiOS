# Testing

Run the complete suite from PowerShell:

```powershell
./scripts/check.ps1
```

`check.ps1` builds normal boot first, then runs the following cases in sequence.
It stops on the first failure. Test scripts launch their own QEMU process, capture
serial output, enforce a 30-second deadline per case, and stop that process on
completion or failure. Logs stay under the reported `build/` directory.

| Script | Cases | Assertions |
| --- | --- | --- |
| `test-boot.ps1` | 128/256/128 MiB | Ordered entry, IDT, and completion markers; no panic/failure; QEMU stays alive until observation |
| `test-exception.ps1` | 128/256 MiB | Ordered fault markers; saved RIP equals the ELF symbol and QEMU vector-6 trace |
| `test-timer.ps1` | 128/256 MiB | Five returns; integer sentinels, CF/DF checks, increasing ticks, repeated kernel vector-32 trace |
| `test-timer.ps1` | Masked IRQ0, 128 MiB | No tick, completion, or kernel vector-32 trace during a two-second host observation |

All cases reject QEMU stderr. Exception and timer cases also reject a triple
fault trace. The normal boot test checks log output, not an independently read
CPU halt state. Timer checks cover integer state and selected flags, not every
architectural register or timing accuracy.

## Individual runs

```powershell
./scripts/build.ps1
./scripts/test-boot.ps1
./scripts/test-exception.ps1
./scripts/test-timer.ps1
```

Boot tests use the existing normal image; exception and timer tests build their
own isolated images. Failed builds can leave an older boot directory in place.
Do not run it as evidence for the failed change. The aggregate command avoids
this by stopping on build errors.

Tool discovery order is an explicit `-LlvmBin`/`-QemuDir` argument, `LLVM_BIN`/
`QEMU_DIR`, `PATH`, then the default directory under Program Files. LLVM tools
must be together; QEMU must include its `share` firmware directory. A missing
tool produces a path-specific error before launch.

The compiler probe in `tests/toolchain/probe.c` is retained from initial bring-up.
It established ELF object generation, not execution, and is not part of the
kernel regression suite.

## Diagnosing failures

| Observation | First check |
| --- | --- |
| Compiler or linker failure | First diagnostic and selected LLVM directory |
| QEMU exits before any kernel output | Captured stderr, firmware path, boot files |
| Firmware runs but no kernel marker | Limine configuration and packaged ELF |
| Revision rejected | Loader hash and requested protocol revision |
| Fault RIP mismatch | Symbol from this test ELF, not an older disassembly |
| Timer waits forever | Ready marker, PIC mask, IRQ trace, and vector-32 gate |
| First IRQ works, later IRQs do not | EOI and return path |
| Masked case reports a tick | Mask programming and whether the intended image booted |

Change one layer at a time. Preserve the failing serial and CPU logs before
rebuilding. Passing tests on the supported QEMU configuration do not establish
real-hardware compatibility, SMP correctness, or fault recovery.

## Command and serial tests

The aggregate check also runs `test-commands.ps1` (17 in-kernel command cases
at each of 128/256 MiB) and `test-echo.ps1` (14 serial scenarios at each memory
size using a local Windows named pipe). Both build isolated images. This brings
the command/serial subtotal to twelve QEMU instances. See [commands.md](commands.md) for exact
coverage, current evidence and limitations. Serial waits have a 30-second
per-response deadline, plus bounded connection and write timeouts.

The suite also includes test-memmap.ps1: three memory-map boots at 128/256/512 MiB,
20 validator checks per boot, and independent checks of usable totals. The aggregate
subtotal is 15 VMs. See [memory-management.md](memory-management.md).

The allocator suite test-pmm.ps1 adds two VMs (128/256 MiB), bringing check.ps1
to 17 runs. It covers invalid operations, capacity boundaries, unique usable page
allocation through exhaustion, and return/reuse of every page. See [physical-pages.md](physical-pages.md).
