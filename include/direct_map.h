#ifndef DHRUTHIOS_DIRECT_MAP_H
#define DHRUTHIOS_DIRECT_MAP_H
#include "pmm.h"
/* Limine revision-0 response layout. See docs/direct-map.md. */
struct direct_map_response {
    uint64_t revision, offset;
};
/* Arithmetic validation only: does not establish that an address is mapped.
 * Trusted readable response and writable output required. Failure leaves output unchanged. */
bool direct_map_address(const struct direct_map_response *response, uint64_t physical,
                        uint64_t *virtual_address);
/* Requires an allocator initialized from the real boot map, single caller/IF clear.
 * Borrowed page pointer: use only while that page remains allocated.
 * Does not create mappings or revoke existing pointers after a free. */
volatile uint8_t *direct_map_page(const struct page_allocator *allocator, uint64_t physical);
#endif
