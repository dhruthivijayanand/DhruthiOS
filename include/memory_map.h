#ifndef DHRUTHIOS_MEMORY_MAP_H
#define DHRUTHIOS_MEMORY_MAP_H
#include <stdbool.h>
#include <stdint.h>

/* Wire layout of Limine's revision-0 memory-map feature. See docs/memory-management.md.
 * Entry bases are physical numbers; response pointers are already virtual. */
struct boot_memory_entry {
    uint64_t base, length, type;
};
struct boot_memory_response {
    uint64_t revision, entry_count;
    struct boot_memory_entry **entries;
};
struct memory_summary {
    uint64_t entries, usable_bytes, usable_pages;
};
enum { MEMORY_USABLE = 0, MEMORY_BOOTLOADER = 5, MEMORY_MAP_LIMIT = 1024 };
/* Trusted, readable bootloader pointers required. On failure output is zeroed.
 * Never dereferences entry base addresses or writes to described memory. */
const char *memory_map_validate(const struct boot_memory_response *map,
                                struct memory_summary *summary);
/* Borrowed bootloader pointers: never reclaim their backing memory. */
const struct boot_memory_response *memory_map_get(void);
bool memory_map_report(void);
#endif
