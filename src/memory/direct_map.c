#include "direct_map.h"
#include <stddef.h>
struct direct_map_request {
    uint64_t id[4], revision;
    struct direct_map_response *response;
};
_Static_assert(sizeof(struct direct_map_response) == 16, "HHDM response layout");
_Static_assert(offsetof(struct direct_map_response, offset) == 8, "HHDM offset layout");
_Static_assert(sizeof(struct direct_map_request) == 48, "HHDM request layout");
_Static_assert(offsetof(struct direct_map_request, response) == 40, "HHDM response pointer");
_Static_assert(sizeof(uintptr_t) == sizeof(uint64_t), "64-bit pointer target");

__attribute__((used, section(".limine_requests"),
               aligned(8))) static volatile struct direct_map_request request = {
    .id = {0xc7b1dd30df4c8b88, 0x0a82e883a194f07b, 0x48dcf1cb8ad2b852, 0x63984e959a98244b},
    .revision = 0,
    .response = 0};

bool direct_map_address(const struct direct_map_response *r, uint64_t physical,
                        uint64_t *virtual_address) {
    if (!r || !virtual_address || r->revision != 0 || !r->offset || r->offset % PMM_PAGE_SIZE ||
        physical % PMM_PAGE_SIZE || physical >= PMM_LIMIT)
        return false;
    /* Check the entire page, not only its first byte. */
    if (r->offset > UINT64_MAX - physical ||
        r->offset + physical > UINT64_MAX - (PMM_PAGE_SIZE - 1))
        return false;
    *virtual_address = r->offset + physical;
    return true;
}

volatile uint8_t *direct_map_page(const struct page_allocator *allocator, uint64_t physical) {
    uint64_t address;
    if (!pmm_is_allocated(allocator, physical) ||
        !direct_map_address(request.response, physical, &address))
        return 0;
    /* The trusted Limine mapping, not the arithmetic check, makes this valid. */
    return (volatile uint8_t *)(uintptr_t)address;
}
