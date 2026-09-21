# Exception handling

## IDT setup

`exceptions_init` installs 256 interrupt gates with the current kernel code
selector. Each gate is present, DPL 0, and uses the current stack (IST index 0).
Compile-time assertions check the gate and IDTR operand layouts. Interrupts
remain disabled after `LIDT`.

Vector 6 enters the invalid-opcode handler. Vector 32 enters the timer handler.
All remaining vectors share a fatal fallback. This fallback reports neither the
vector nor a decoded error code; it has not been exercised by the current tests.
There is no TSS, alternate fault stack, privilege transition, or fault recovery.

## Invalid opcode: Assembly to C

`UD2` raises #UD without a CPU error code. `exception_ud_entry` reads the saved
RIP at the top of the interrupt frame and passes it as the first System V integer
argument in RDI. It clears the direction flag and aligns RSP to 16 bytes before
calling C.

`exception_panic_ud` prints the fault address as 16 hexadecimal digits, then
enters a `CLI; HLT` loop. This fatal path does not restore registers or execute
`IRETQ`. It cannot resume the interrupted code. The generic fallback also never
returns, so it does not need to normalize error-code and no-error-code frames.

Using the current stack keeps bring-up small, but a corrupt or exhausted stack
can prevent even the panic handler from working. Nested faults and double-fault
handling need a separate design before this becomes a general exception layer.

## Verification

```powershell
./scripts/test-exception.ps1
```

The test builds an isolated image under `build/ud2`. It resolves the address of
`exception_test_ud` from that ELF, then checks that the serial RIP and QEMU's
vector-6 trace both identify that address. It rejects an unexpected return,
normal-boot completion, generic panic, early VM exit, timeout, and QEMU stderr.
The two cases use 128 and 256 MiB RAM.

The deliberate fault helper is linked only into the fault-test image. See
[testing](testing.md) for the full regression command and log locations.

## References

- [Intel SDM](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html), Volume 3A: interrupt gates, interrupt stack frames, and exception classification.
- [x86-64 System V ABI](https://gitlab.com/x86-psABIs/x86-64-ABI/-/blob/master/x86-64-ABI/low-level-sys-info.tex): argument registers, stack alignment, and direction flag.
