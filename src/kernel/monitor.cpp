#include "monitor.h"
#include "text_buffer.hpp"
extern "C" {
#include "commands.h"
#include "direct_map.h"
#include "serial.h"
}
namespace {
page_allocator pool; // Static zero initialization; no runtime constructor.
bool matches(const char *line, unsigned length, const char *word, unsigned size) {
    if (!line || length != size)
        return false;
    for (unsigned i = 0; i < length; ++i)
        if (line[i] != word[i])
            return false;
    return true;
}
bool memory_report() {
    TextBuffer<256> report;
    report.append("Memory (4096-byte pages): managed=");
    report.decimal(pool.total);
    report.append(" free=");
    report.decimal(pool.free);
    report.append(" used=");
    report.decimal(pool.total - pool.free);
    report.append(" excluded=");
    report.decimal(pool.excluded);
    report.append("\r\nPhysical address limit: 1 GiB; kernel and reserved regions excluded.\r\n");
    return report.text() && serial_write(report.text());
}
bool memory_test() {
    const uint64_t before = pool.free;
    uint64_t pages[2];
    unsigned acquired = 0;
    while (acquired < 2 && pmm_alloc(&pool, &pages[acquired]))
        ++acquired;
    bool passed = acquired == 2;
    if (passed) {
        volatile uint8_t *a = direct_map_page(&pool, pages[0]);
        volatile uint8_t *b = direct_map_page(&pool, pages[1]);
        passed = a && b && a != b;
        if (passed) {
            for (unsigned round = 0; round < 2; ++round) {
                for (unsigned i = 0; i < PMM_PAGE_SIZE; ++i) {
                    a[i] = (uint8_t)(i ^ (round ? 0xaa : 0x55));
                    b[i] = (uint8_t)(i ^ (round ? 0x55 : 0xaa));
                }
                for (unsigned i = 0; i < PMM_PAGE_SIZE; ++i)
                    if (a[i] != (uint8_t)(i ^ (round ? 0xaa : 0x55)) ||
                        b[i] != (uint8_t)(i ^ (round ? 0x55 : 0xaa)))
                        passed = false;
            }
        }
    }
    // Cleanup every acquired page even on partial allocation or pattern failure.
    bool released = true;
    for (unsigned i = 0; i < acquired; ++i)
        if (!pmm_free(&pool, pages[i]))
            released = false;
    if (!released || pool.free != before)
        return serial_write("PANIC: memory-test cleanup failed\r\n"), false;
    if (acquired < 2)
        return serial_write("Memory test unavailable: two free pages required.\r\n");
    if (!passed)
        return serial_write("PANIC: memory-test readback failed\r\n"), false;
    return serial_write("MEMTEST PASS: two pages written, verified and returned.\r\n");
}
} // namespace
extern "C" bool monitor_init(void) { return pmm_init(&pool, memory_map_get()); }
extern "C" bool monitor_execute(const char *line, unsigned length) {
    if (!pool.initialized)
        return false;
    if (matches(line, length, "help", 4))
        return serial_write("Commands:\r\n  help  - list commands\r\n"
                            "  about - describe DhruthiOS\r\n"
                            "  memory - show page counts\r\n"
                            "  memtest - test two pages and return them\r\n");
    if (matches(line, length, "about", 5))
        return serial_write("DhruthiOS: an educational x86-64 kernel.\r\n"
                            "Assembly interrupt entry, C services, C++ monitor.\r\n"
                            "Running inside QEMU; commands execute in the kernel.\r\n");
    if (matches(line, length, "memory", 6))
        return memory_report();
    if (matches(line, length, "memtest", 7))
        return memory_test();
    return serial_write(command_response(line, length));
}
