#include "text_buffer.hpp"
extern "C" {
#include "kernel-tests.h"
#include "serial.h"
}
#define CHECK(x)                                                                                   \
    do {                                                                                           \
        if (!(x)) {                                                                                \
            serial_write("FAIL: text buffer: " #x "\r\n");                                         \
            return false;                                                                          \
        }                                                                                          \
    } while (0)
static bool equals(const char *a, const char *b) {
    if (!a)
        return false;
    while (*a && *a == *b) {
        ++a;
        ++b;
    }
    return *a == *b;
}
extern "C" bool format_tests_run(void) {
    TextBuffer<1> empty;
    CHECK(equals(empty.text(), ""));
    CHECK(empty.append("") && !empty.append("x") && !empty.text());
    TextBuffer<4> exact;
    CHECK(exact.append("abc") && equals(exact.text(), "abc"));
    CHECK(!exact.append("d") && !exact.text() && !exact.append(""));
    TextBuffer<21> maximum;
    CHECK(maximum.decimal(UINT64_MAX) && equals(maximum.text(), "18446744073709551615"));
    TextBuffer<2> zero;
    CHECK(zero.decimal(0) && equals(zero.text(), "0"));
    TextBuffer<2> short_number;
    CHECK(!short_number.decimal(10) && !short_number.text());
    TextBuffer<4> null_input;
    CHECK(!null_input.append(nullptr) && !null_input.text());
    return serial_write("PASS: C++ text buffer boundary tests completed\r\n");
}
