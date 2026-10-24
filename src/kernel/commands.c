#include "commands.h"

/* Compare a bounded input span; the input need not be NUL-terminated. */
static int matches(const char *line, unsigned length, const char *word, unsigned word_length) {
    if (length != word_length) {
        return 0;
    }
    for (unsigned i = 0; i < length; ++i) {
        if (line[i] != word[i]) {
            return 0;
        }
    }
    return 1;
}

const char *command_response(const char *line, unsigned length) {
    if (length == 0) {
        return "No command entered.\r\n";
    }
    if (!line) {
        return "Invalid command input.\r\n";
    }
    if (matches(line, length, "help", 4)) {
        return "Commands:\r\n"
               "  help  - list commands\r\n"
               "  about - describe DhruthiOS\r\n";
    }
    if (matches(line, length, "about", 5)) {
        return "DhruthiOS: an educational x86-64 kernel.\r\n"
               "Written in C and Assembly; running inside QEMU.\r\n"
               "This command interface runs inside the kernel.\r\n";
    }
    return "Unknown command. Try help.\r\n";
}