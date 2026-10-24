#include "memory_map.h"
#include "serial.h"
#include <stddef.h>

struct memory_request {
    uint64_t id[4], revision;
    struct boot_memory_response *response;
};
_Static_assert(sizeof(struct boot_memory_entry) == 24, "entry layout");
_Static_assert(sizeof(struct boot_memory_response) == 24, "response layout");
_Static_assert(offsetof(struct boot_memory_response, entries) == 16, "entries offset");
_Static_assert(sizeof(struct memory_request) == 48, "request layout");
_Static_assert(offsetof(struct memory_request, response) == 40, "response offset");

__attribute__((used, section(".limine_requests"),
               aligned(8))) static volatile struct memory_request request = {
    .id = {0xc7b1dd30df4c8b88, 0x0a82e883a194f07b, 0x67cf3d9d378a806f, 0xe304acdfc50c3c62},
    .revision = 0,
    .response = 0};

static bool protected_from_overlap(uint64_t type) {
    return type == MEMORY_USABLE || type == MEMORY_BOOTLOADER;
}

const char *memory_map_validate(const struct boot_memory_response *map,
                                struct memory_summary *summary) {
    if (!summary)
        return "missing summary";
    summary->entries = 0;
    summary->usable_bytes = 0;
    summary->usable_pages = 0;
    if (!map)
        return "missing response";
    if (map->revision != 0)
        return "unsupported response revision";
    if (map->entry_count == 0 || map->entry_count > MEMORY_MAP_LIMIT)
        return "unsupported entry count";
    if (!map->entries)
        return "missing entry array";
    uint64_t usable = 0;
    for (uint64_t i = 0; i < map->entry_count; ++i) {
        const struct boot_memory_entry *entry = map->entries[i];
        if (!entry)
            return "missing entry";
        if (!entry->length)
            return "zero length";
        if (entry->length > UINT64_MAX - entry->base)
            return "range overflow";
        if (i && entry->base < map->entries[i - 1]->base)
            return "unsorted map";
        if (protected_from_overlap(entry->type) && ((entry->base & 4095) || (entry->length & 4095)))
            return "unaligned usable or bootloader region";
        for (uint64_t j = 0; j < i; ++j) {
            const struct boot_memory_entry *other = map->entries[j];
            if ((protected_from_overlap(entry->type) || protected_from_overlap(other->type)) &&
                entry->base < other->base + other->length &&
                other->base < entry->base + entry->length)
                return "overlapping usable or bootloader region";
        }
        if (entry->type == MEMORY_USABLE) {
            if (entry->length > UINT64_MAX - usable)
                return "usable total overflow";
            usable += entry->length;
        }
    }
    summary->entries = map->entry_count;
    summary->usable_bytes = usable;
    summary->usable_pages = usable / 4096;
    return 0;
}

static bool number(uint64_t value, unsigned radix) {
    static const char digits[] = "0123456789abcdef";
    char buffer[21];
    unsigned position = sizeof(buffer) - 1;
    buffer[position] = 0;
    do {
        buffer[--position] = digits[value % radix];
        value /= radix;
    } while (value);
    return serial_write(&buffer[position]);
}

bool memory_map_report(void) {
    const struct boot_memory_response *map = request.response;
    struct memory_summary summary;
    const char *error = memory_map_validate(map, &summary);
    if (error) {
        (void)serial_write("FAIL: memory map: ");
        (void)serial_write(error);
        (void)serial_write("\r\n");
        return false;
    }
    for (uint64_t i = 0; i < map->entry_count; ++i) {
        const struct boot_memory_entry *entry = map->entries[i];
        if (!serial_write("MAP: base=0x") || !number(entry->base, 16) ||
            !serial_write(" length=0x") || !number(entry->length, 16) || !serial_write(" type=") ||
            !number(entry->type, 10) || !serial_write("\r\n"))
            return false;
    }
    return serial_write("MEMORY: entries=") && number(summary.entries, 10) &&
           serial_write(" usable_bytes=") && number(summary.usable_bytes, 10) &&
           serial_write(" usable_pages=") && number(summary.usable_pages, 10) &&
           serial_write("\r\n");
}
