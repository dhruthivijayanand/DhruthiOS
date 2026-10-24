# Command handling and serial input

`main.c` owns startup, bounded input collection, editing, and output.
`src/kernel/commands.c` selects response text. `include/commands.h` declares
`command_response(line, length)`. It returns immutable static text, does no
allocation or hardware access, and does not modify its input. Input is a
readable span of the stated length; it need not be zero-terminated.
Exact, case-sensitive commands are help and about. Whitespace is not trimmed.

## Input and limitations

The echo image accepts 31 printable ASCII characters in a 32-byte buffer.
Backspace and DEL edit only nonempty input. CR, LF and CRLF end a line.
Overflow rejects the whole line and discards bytes through Enter.
The kernel polls continuously. This is a kernel monitor, not a user-space
shell or physical keyboard driver. Escape sequences, arrows, Unicode, history
and concurrency are unsupported. Printable parts of escape sequences can
still enter the buffer: ignoring control bytes is not an escape parser.

## Run

```powershell
& ./scripts/build.ps1 -LlvmBin 'D:\Program Files\LLVM\bin' -Mode echo
& ./scripts/run-echo.ps1
```

In QEMU press Ctrl+Alt+2, type help or about and press Enter. Close QEMU
before rebuilding. The new runner wraps the previously used launch command.

## Automated tests

```powershell
& ./scripts/test-commands.ps1 -LlvmBin 'D:\Program Files\LLVM\bin'
& ./scripts/test-echo.ps1 -LlvmBin 'D:\Program Files\LLVM\bin'
```

The first script runs 17 command cases in an isolated kernel image at each
of 128/256 MiB: exact commands, empty/null input, nonterminated spans, explicit
length, prefixes/suffixes, case, whitespace, embedded zeros, boundaries, repeats.

The second uses a unique local Windows named pipe to send input to the actual
interactive kernel. Fourteen scenarios per memory size compare exact serial
output, including CR/LF/CRLF, Backspace/DEL, empty edits, the capacity boundary,
overflow suffix discard, and recovery. It uses no network connection.
Each script times out and closes only its own VM, preserving logs in build/.
These tests do not verify physical key delivery through the SDL GUI.

## Evidence — 2026-10-24

- 17 command cases passed at each of 128/256 MiB:
  `build/commands/test-4e1acb0ab8d7425b8bd5de099f365831/`.
- 14 serial scenarios passed at each of 128/256 MiB:
  `build/echo/test-121fc351435041a78219757b32b2dbaf/`.
- All eight original boot, exception and timer cases passed.
- New graphical runner syntax checked; GUI operation not repeated this milestone.

Command selection: IMPLEMENTED. Overall interactive monitor: PROTOTYPE.

## Interview point

Input collection decides which bytes form a line; command selection decides
what the line means; serial output displays its response. Separating these
responsibilities makes testing easier without introducing processes or privilege
boundaries. No allocator, scheduler, or C++ component is claimed.
