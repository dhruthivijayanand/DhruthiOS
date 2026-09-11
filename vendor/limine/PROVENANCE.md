# Limine dependency

- Release page: https://github.com/limine-bootloader/limine/releases/tag/v12.5.2
- User downloaded `limine-binary.tar.gz`; extracted only BOOTX64.EFI and LICENSE.
- Loader contains the version string `Limine 12.5.2 (x86-64, UEFI)`.
- Archive SHA-256: `4C760C09C53560D859B362319A3DC63B79CCA3D47F35D69AB0106A13B8057055`
- BOOTX64.EFI SHA-256: `D257ADD3B8CA480470C50BA5E55899702F19B10D9B29DC8D4A5DB97FC4FB8B19`
- Hashes were measured locally for reproducibility; an upstream signature was not verified.
- License: BSD-2-Clause; supplied LICENSE retained alongside the binary.
- Limine is third-party software, not authored as part of DhruthiOS.
- Kernel requests Limine base revision 6 using the protocol-defined marker arrays.
  No full protocol header is needed for this initial revision-only handshake.

Protocol source consulted 2026-09-11:
https://github.com/limine-bootloader/limine-protocol/blob/trunk/PROTOCOL.md

The protocol values and required revision are fixed in `src/kernel/main.c`.
Boot success must also be tested when changing the loader or protocol revision.
