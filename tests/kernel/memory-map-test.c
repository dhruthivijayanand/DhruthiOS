#include "memory_map.h"
#include "serial.h"
#include <stdint.h>
#define CHECK(condition)                                                                           \
    do {                                                                                           \
        if (!(condition)) {                                                                        \
            (void)serial_write("FAIL: memory validator case " #condition "\r\n");                  \
            return false;                                                                          \
        }                                                                                          \
        ++checks;                                                                                  \
    } while (0)

bool memory_map_tests_run(void) {
    unsigned checks = 0;
    struct memory_summary s;
    struct boot_memory_entry a = {0x1000, 0x2000, MEMORY_USABLE};
    struct boot_memory_entry b = {0x3000, 0x1000, 6};
    struct boot_memory_entry *entries[] = {&a, &b};
    struct boot_memory_response map = {0, 2, entries};
    CHECK(memory_map_validate(&map, &s) == 0 && s.entries == 2 && s.usable_bytes == 8192 &&
          s.usable_pages == 2);
    CHECK(memory_map_validate(0, &s) != 0 && s.usable_bytes == 0);
    CHECK(memory_map_validate(&map, 0) != 0);
    map.revision = 1;
    CHECK(memory_map_validate(&map, &s) != 0);
    map.revision = 0;
    map.entry_count = 0;
    CHECK(memory_map_validate(&map, &s) != 0);
    map.entry_count = MEMORY_MAP_LIMIT + 1;
    CHECK(memory_map_validate(&map, &s) != 0);
    map.entry_count = 2;
    map.entries = 0;
    CHECK(memory_map_validate(&map, &s) != 0);
    map.entries = entries;
    entries[1] = 0;
    CHECK(memory_map_validate(&map, &s) != 0 && s.usable_bytes == 0);
    entries[1] = &b;
    b.length = 0;
    CHECK(memory_map_validate(&map, &s) != 0);
    b.base = UINT64_MAX - 1;
    b.length = 4;
    CHECK(memory_map_validate(&map, &s) != 0);
    b.base = 0;
    b.length = 4096;
    CHECK(memory_map_validate(&map, &s) != 0);
    b.base = 0x2000;
    CHECK(memory_map_validate(&map, &s) != 0);
    b.base = 0x3000;
    a.base = 0x1001;
    a.length = 4096;
    CHECK(memory_map_validate(&map, &s) != 0);
    a.base = 0x1000;
    a.length = 4095;
    CHECK(memory_map_validate(&map, &s) != 0);
    a.length = 4096;
    a.type = MEMORY_BOOTLOADER;
    CHECK(memory_map_validate(&map, &s) == 0 && s.usable_bytes == 0);
    a.base = 0x1001;
    CHECK(memory_map_validate(&map, &s) != 0);
    a.base = 0x1000;
    a.length = 0x3000;
    CHECK(memory_map_validate(&map, &s) != 0);
    a.type = 1;
    CHECK(memory_map_validate(&map, &s) == 0 && s.usable_bytes == 0);
    a.type = 999;
    CHECK(memory_map_validate(&map, &s) == 0 && s.usable_bytes == 0);
    a.base = 0;
    a.length = 4096;
    a.type = MEMORY_USABLE;
    CHECK(memory_map_validate(&map, &s) == 0 && s.usable_pages == 1);
    if (checks != 20)
        return false;
    return serial_write("PASS: memory validator completed (20 cases)\r\n");
}
