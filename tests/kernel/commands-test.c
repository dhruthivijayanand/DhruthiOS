#include "commands.h"
#include "serial.h"
#include <stdbool.h>

static bool text_equal(const char *left, const char *right) {
    while (*left && *left == *right) {
        ++left;
        ++right;
    }
    return *left == *right;
}

bool command_tests_run(void) {
    static const char raw_help[4] = {'h', 'e', 'l', 'p'};
    static const char embedded_zero[4] = {'h', 'e', 0, 'p'};
    static const char boundary[32] = "1234567890123456789012345678901";
    static const char help[] = "Commands:\r\n  help  - list commands\r\n"
                               "  about - describe DhruthiOS\r\n";
    static const char about[] = "DhruthiOS: an educational x86-64 kernel.\r\n"
                                "Written in C and Assembly; running inside QEMU.\r\n"
                                "This command interface runs inside the kernel.\r\n";
    static const char unknown[] = "Unknown command. Try help.\r\n";
    static const struct {
        const char *name;
        const char *input;
        unsigned length;
        const char *expected;
    } cases[] = {{"empty", "", 0, "No command entered.\r\n"},
                 {"null empty", 0, 0, "No command entered.\r\n"},
                 {"null nonempty", 0, 4, "Invalid command input.\r\n"},
                 {"help", "help", 4, help},
                 {"about", "about", 5, about},
                 {"nonterminated span", raw_help, 4, help},
                 {"explicit prefix span", "helpful", 4, help},
                 {"help suffix", "helpful", 7, unknown},
                 {"about suffix", "abouts", 6, unknown},
                 {"short prefix", "hel", 3, unknown},
                 {"uppercase", "HELP", 4, unknown},
                 {"leading space", " help", 5, unknown},
                 {"trailing space", "help ", 5, unknown},
                 {"embedded zero", embedded_zero, 4, unknown},
                 {"31 characters", boundary, 31, unknown},
                 {"32-byte span", boundary, 32, unknown},
                 {"repeat help", "help", 4, help}};
    for (unsigned i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        if (!text_equal(command_response(cases[i].input, cases[i].length), cases[i].expected)) {
            (void)serial_write("FAIL: command case ");
            (void)serial_write(cases[i].name);
            (void)serial_write("\r\n");
            return false;
        }
        if (!serial_write("CASE PASS: ") || !serial_write(cases[i].name) || !serial_write("\r\n")) {
            return false;
        }
    }
    return serial_write("PASS: command tests completed (17 cases)\r\n");
}