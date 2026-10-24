#ifndef DHRUTHIOS_TEXT_BUFFER_HPP
#define DHRUTHIOS_TEXT_BUFFER_HPP
#include <stdint.h>
/* Fixed storage; no heap, exceptions or library calls. Append failure is sticky.
 * Inputs must be readable terminated strings and must not alias this buffer. */
template <unsigned Capacity> class TextBuffer {
    static_assert(Capacity > 0, "Need room for the terminator");
    char bytes_[Capacity];
    unsigned used_ = 0;
    bool valid_ = true;

  public:
    TextBuffer() { bytes_[0] = 0; }
    bool append(const char *text) {
        if (!valid_ || !text) {
            valid_ = false;
            return false;
        }
        while (*text) {
            if (used_ == Capacity - 1) {
                valid_ = false;
                return false;
            }
            bytes_[used_++] = *text++;
            bytes_[used_] = 0;
        }
        return true;
    }
    bool decimal(uint64_t value) {
        char digits[21];
        unsigned pos = 20;
        digits[pos] = 0;
        do {
            digits[--pos] = (char)('0' + value % 10);
            value /= 10;
        } while (value);
        return append(&digits[pos]);
    }
    const char *text() const { return valid_ ? bytes_ : nullptr; }
};
#endif
