#include "pmm.h"
#include "serial.h"
static struct page_allocator synthetic, actual, empty;
static uint8_t seen[PMM_PAGE_COUNT];
#define CHECK(condition)                                                                           \
    do {                                                                                           \
        if (!(condition)) {                                                                        \
            (void)serial_write("FAIL: pmm: " #condition "\r\n");                                   \
            return false;                                                                          \
        }                                                                                          \
    } while (0)

bool pmm_tests_run(void) {
    uint64_t address = UINT64_MAX, first, last;
    struct boot_memory_entry zero = {0, 3 * PMM_PAGE_SIZE, MEMORY_USABLE};
    struct boot_memory_entry reserved = {3 * PMM_PAGE_SIZE, PMM_PAGE_SIZE, 1};
    struct boot_memory_entry loader = {4 * PMM_PAGE_SIZE, PMM_PAGE_SIZE, MEMORY_BOOTLOADER};
    struct boot_memory_entry edge = {PMM_LIMIT - PMM_PAGE_SIZE, 3 * PMM_PAGE_SIZE, MEMORY_USABLE};
    struct boot_memory_entry *entries[] = {&zero, &reserved, &loader, &edge};
    struct boot_memory_response map = {0, 4, entries};
    CHECK(!pmm_alloc(&synthetic, &address) && address == UINT64_MAX);
    CHECK(!pmm_free(&synthetic, PMM_PAGE_SIZE));
    CHECK(!pmm_init(0, &map));
    CHECK(!pmm_init(&synthetic, 0) && !synthetic.initialized);
    zero.length = 4 * PMM_PAGE_SIZE;
    CHECK(!pmm_init(&synthetic, &map) && !synthetic.initialized);
    zero.length = 3 * PMM_PAGE_SIZE;
    struct boot_memory_entry *empty_entries[] = {&reserved};
    struct boot_memory_response empty_map = {0, 1, empty_entries};
    CHECK(pmm_init(&empty, &empty_map) && empty.total == 0);
    CHECK(!pmm_alloc(&empty, &address) && address == UINT64_MAX);
    CHECK(!pmm_alloc(0, &address) && !pmm_free(0, PMM_PAGE_SIZE));
    CHECK(pmm_init(&synthetic, &map));
    CHECK(synthetic.total == 3 && synthetic.free == 3 && synthetic.excluded == 3);
    CHECK(!pmm_init(&synthetic, &map));
    CHECK(!pmm_alloc(&synthetic, 0) && synthetic.free == 3);
    CHECK(!pmm_free(&synthetic, 0));
    CHECK(!pmm_free(&synthetic, PMM_PAGE_SIZE));
    CHECK(!pmm_free(&synthetic, 3 * PMM_PAGE_SIZE));
    CHECK(!pmm_free(&synthetic, 4 * PMM_PAGE_SIZE));
    CHECK(!pmm_free(&synthetic, PMM_LIMIT));
    CHECK(!pmm_free(&synthetic, UINT64_MAX));
    CHECK(pmm_alloc(&synthetic, &first) && first == PMM_PAGE_SIZE);
    CHECK(!pmm_free(&synthetic, first + 1));
    CHECK(pmm_alloc(&synthetic, &address) && address == 2 * PMM_PAGE_SIZE);
    CHECK(pmm_alloc(&synthetic, &last) && last == PMM_LIMIT - PMM_PAGE_SIZE);
    address = UINT64_MAX;
    CHECK(!pmm_alloc(&synthetic, &address) && address == UINT64_MAX && synthetic.free == 0);
    CHECK(pmm_free(&synthetic, first));
    CHECK(!pmm_free(&synthetic, first) && synthetic.free == 1);
    CHECK(pmm_alloc(&synthetic, &address) && address == first);
    CHECK(pmm_free(&synthetic, first) && pmm_free(&synthetic, 2 * PMM_PAGE_SIZE) &&
          pmm_free(&synthetic, last) && synthetic.free == synthetic.total);
    CHECK(serial_write("PASS: allocator boundary and invalid-free checks\r\n"));

    const struct boot_memory_response *boot = memory_map_get();
    CHECK(pmm_init(&actual, boot) && actual.total > 0);
    struct memory_summary summary;
    CHECK(!memory_map_validate(boot, &summary));
    uint64_t expected = 0;
    for (uint64_t i = 0; i < boot->entry_count; ++i) {
        const struct boot_memory_entry *e = boot->entries[i];
        if (e->type != MEMORY_USABLE)
            continue;
        uint64_t first_page = e->base / PMM_PAGE_SIZE;
        uint64_t end_page = (e->base + e->length) / PMM_PAGE_SIZE;
        if (first_page == 0)
            first_page = 1;
        if (end_page > PMM_PAGE_COUNT)
            end_page = PMM_PAGE_COUNT;
        if (first_page < end_page)
            expected += end_page - first_page;
    }
    CHECK(actual.total == expected && actual.excluded == summary.usable_pages - expected);
    uint64_t count = 0;
    while (pmm_alloc(&actual, &address)) {
        CHECK(address && address < PMM_LIMIT && address % PMM_PAGE_SIZE == 0);
        unsigned page = (unsigned)(address / PMM_PAGE_SIZE);
        CHECK(!seen[page]);
        bool usable = false;
        for (uint64_t i = 0; i < boot->entry_count; ++i) {
            const struct boot_memory_entry *e = boot->entries[i];
            if (e->type == MEMORY_USABLE && address >= e->base && address < e->base + e->length)
                usable = true;
        }
        CHECK(usable);
        seen[page] = 1;
        ++count;
    }
    CHECK(count == actual.total && actual.free == 0);
    CHECK(serial_write("PASS: real map exhausted; all pages unique and usable\r\n"));
    for (unsigned page = 0; page < PMM_PAGE_COUNT; ++page)
        if (seen[page])
            CHECK(pmm_free(&actual, (uint64_t)page * PMM_PAGE_SIZE));
    CHECK(actual.free == actual.total);
    CHECK(pmm_alloc(&actual, &address) && pmm_free(&actual, address));
    CHECK(actual.free == actual.total);
    return serial_write("PASS: allocator tests completed; all pages returned\r\n");
}
