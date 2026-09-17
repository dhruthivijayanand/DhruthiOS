# Decision: existing Limine with QEMU UEFI for the first boot

Context: Windows host, beginner kernel project with limited development time, native LLVM available, no WSL
or native ISO builder discovered. QEMU includes x86-64 UEFI firmware.

Alternatives: BIOS-first Limine ISO; install Unix build tools; custom loader;
UEFI Limine with a directory-backed virtual FAT disk.

Chosen approach: Limine 12.5.2 BOOTX64.EFI with QEMU's bundled UEFI firmware,
virtual FAT view of build/esp, and temporary snapshot writes. This replaces the
initial provisional BIOS-first choice based on the actual tools found.

Reason: get a documented 64-bit kernel handoff with minimal additional host setup.

Trade-offs: this deliverable needs QEMU and the boot directory; it is not a
standalone ISO or real-machine installer. No BIOS compatibility claim is made.

Consequences: own the entry, protocol revision check, serial code and ELF layout.
Credit Limine for bootloading and initial CPU/stack/page-table setup. Preserve
its license and measured dependency hashes. Stop QEMU before modifying boot
files. Use only the project boot tree as the guest disk source.

Evidence: repeated UEFI boots and the interactive run passed; see development-log.
