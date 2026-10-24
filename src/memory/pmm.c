#include "pmm.h"
enum { RESERVED, FREE, ALLOCATED };

bool pmm_init(struct page_allocator *a, const struct boot_memory_response *map) {
    struct memory_summary summary;
    if (!a || a->initialized || memory_map_validate(map, &summary))
        return false;
    /* Volatile stores deliberately avoid a compiler-generated hosted memset.
     * They do not make this allocator thread-safe. */
    for (unsigned i = 0; i < PMM_PAGE_COUNT; ++i)
        a->state[i] = RESERVED;
    a->total = 0;
    a->cursor = 1;
    for (uint64_t i = 0; i < map->entry_count; ++i) {
        const struct boot_memory_entry *e = map->entries[i];
        if (e->type != MEMORY_USABLE || e->base >= PMM_LIMIT)
            continue;
        uint64_t end = e->base + e->length;
        if (end > PMM_LIMIT)
            end = PMM_LIMIT;
        uint64_t base = e->base ? e->base : PMM_PAGE_SIZE;
        for (uint64_t address = base; address < end; address += PMM_PAGE_SIZE) {
            a->state[address / PMM_PAGE_SIZE] = FREE;
            ++a->total;
        }
    }
    a->free = a->total;
    a->excluded = summary.usable_pages - a->total;
    a->initialized = true;
    return true;
}

bool pmm_alloc(struct page_allocator *a, uint64_t *physical) {
    if (!a || !a->initialized || !physical || !a->free)
        return false;
    for (unsigned scanned = 0; scanned < PMM_PAGE_COUNT; ++scanned) {
        unsigned page = a->cursor;
        a->cursor = (page + 1) % PMM_PAGE_COUNT;
        if (a->state[page] == FREE) {
            a->state[page] = ALLOCATED;
            --a->free;
            *physical = (uint64_t)page * PMM_PAGE_SIZE;
            return true;
        }
    }
    return false;
}

bool pmm_free(struct page_allocator *a, uint64_t physical) {
    if (!a || !a->initialized || physical >= PMM_LIMIT || physical % PMM_PAGE_SIZE)
        return false;
    unsigned page = (unsigned)(physical / PMM_PAGE_SIZE);
    if (a->state[page] != ALLOCATED)
        return false;
    a->state[page] = FREE;
    ++a->free;
    return true;
}

bool pmm_is_allocated(const struct page_allocator *a, uint64_t physical) {
    return a && a->initialized && physical < PMM_LIMIT && physical % PMM_PAGE_SIZE == 0 &&
           a->state[physical / PMM_PAGE_SIZE] == ALLOCATED;
}