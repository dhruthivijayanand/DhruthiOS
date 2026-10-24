#ifndef DHRUTHIOS_PMM_H
#define DHRUTHIOS_PMM_H
#include "memory_map.h"
#define PMM_PAGE_SIZE UINT64_C(4096)
#define PMM_LIMIT (UINT64_C(1024) * 1024 * 1024)
#define PMM_PAGE_COUNT (PMM_LIMIT / PMM_PAGE_SIZE)
/* Static, zero-initialized storage required. Single caller, interrupts disabled.
 * Treat fields as private. Physical addresses are numbers, not C pointers. */
struct page_allocator {
    volatile uint8_t state[PMM_PAGE_COUNT];
    uint64_t total, free, excluded;
    unsigned cursor;
    bool initialized;
};
bool pmm_init(struct page_allocator *allocator, const struct boot_memory_response *map);
bool pmm_alloc(struct page_allocator *allocator, uint64_t *physical);
bool pmm_free(struct page_allocator *allocator, uint64_t physical);
bool pmm_is_allocated(const struct page_allocator *allocator, uint64_t physical);
#endif
