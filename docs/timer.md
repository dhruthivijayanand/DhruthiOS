# PIT timer interrupt

## Device setup

The timer targets QEMU's single-CPU PC model using the legacy PIT and PIC.
`timer_init` requires the kernel IDT and leaves IF clear. It disables the local
APIC for direct PIC delivery, remaps the master/slave PIC to vectors 32/40,
programs PIT channel 0 in mode 2 with divisor 11932, and unmasks only IRQ0.
The requested rate is approximately 100 Hz; its accuracy has not been measured.
Timer test VMs disable HPET to keep routing fixed.

Normal boot does not call `timer_init`. The monitor now activates the timer for idle waiting; the focused test images remain. This is not a scheduler or an APIC
driver. The PIC writes omit physical-device I/O delays because the supported
target is QEMU.

## Returning from an interrupt

Unlike the fatal exception path, IRQ0 must resume interrupted code. The Assembly
entry saves all 15 non-RSP general-purpose registers, clears DF, and aligns the
stack before calling `timer_on_irq`. RBX retains the original saved-register
stack pointer across the C call. The entry then restores registers and executes
`IRETQ` using the CPU's interrupt frame.

The C handler increments a tick counter and sends EOI to the master PIC. It does
not allocate memory or write serial output. `timer_ticks` is read with IF clear
on the single CPU; `volatile` alone is not a synchronization scheme for SMP.
No FP/SIMD state is saved.

## Verification

```powershell
./scripts/test-timer.ps1
```

The test-only `timer_wait_probe` plants distinct values in the 15 saved registers,
sets CF and DF, and executes `STI; HLT`. After interrupt return it disables
interrupts, checks the sentinels and selected flags, and clears DF before
returning to C. Handler instrumentation checks that C observed DF clear.
Each positive case requires five successful waits and increasing tick counts;
QEMU's trace independently confirms vector 32 in kernel code.

A separate image leaves IRQ0 masked. For two host seconds after its waiting
marker, the test requires no tick, completion marker, or kernel vector-32 trace.
This checks that the positive result depends on interrupt delivery. It is not a
calibration of the guest clock.

Positive cases run with 128 and 256 MiB; the masked control uses 128 MiB.
Untested: sustained interrupt load, real hardware, the x2APIC transition branch,
other IRQs, FP/SIMD contexts, SMP, and nested faults.

## References

- [Intel SDM](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html): interrupt return and APIC mode transitions.
- QEMU 11.1.0: [PIT](https://github.com/qemu/qemu/blob/v11.1.0/hw/timer/i8254.c), [PIT clock](https://github.com/qemu/qemu/blob/v11.1.0/include/hw/timer/i8254.h), [PIC](https://github.com/qemu/qemu/blob/v11.1.0/hw/intc/i8259.c), [APIC routing](https://github.com/qemu/qemu/blob/v11.1.0/hw/intc/apic.c).

The integrated monitor tests ticks before and after memory commands and requires
increasing counts while idle. It runs services with IF clear and enables IRQ0
only during STI; HLT; CLI waits. This counts delivered events, not wall-clock uptime.
