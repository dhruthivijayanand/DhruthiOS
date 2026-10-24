# Complete the educational kernel before adding new subsystems

Decision: integrate existing timer and memory mechanisms into the monitor and
freeze the submission scope at a tested single-CPU QEMU kernel.

Context: a near submission deadline and a beginner learning the architecture.

Alternatives: add a filesystem, user processes, scheduling or more drivers;
leave all mechanisms available only in separate test images.

Chosen approach: keep the verified boot baseline and focused test images, and
provide one monitor demonstrating memory services and timer wakeups. Package
the saved source only after a fresh-copy build and all automated tests pass.

Reason: the demonstration should connect the mechanisms already built, while
preserving evidence and keeping the implementation explainable.

Trade-offs: the monitor is privileged and lacks application isolation. ticks
is a delivered-interrupt counter, not an uptime clock. Input is still polled,
with timer-based waiting when idle.

Consequences: the project can honestly demonstrate boot, interrupt entry/return,
allocation, address mapping, bounded input and limited freestanding C++. New
subsystems remain future work with their own design and verification needs.
