#include "direct_map.h"
#include "serial.h"
static struct page_allocator pool;
#define CHECK(condition)                                                                           \
    do {                                                                                           \
        if (!(condition)) {                                                                        \
            (void)serial_write("FAIL: direct map: " #condition "\r\n");                            \
            return false;                                                                          \
        }                                                                                          \
    } while (0)

bool direct_map_tests_run(void) {
    /* Example offsets test arithmetic only; they are never dereferenced. */
    struct direct_map_response example = {0, UINT64_C(0xffff800000000000)};
    uint64_t result = UINT64_MAX;
    CHECK(!direct_map_address(0, PMM_PAGE_SIZE, &result) && result == UINT64_MAX);
    CHECK(!direct_map_address(&example, PMM_PAGE_SIZE, 0));
    example.revision = 1;
    CHECK(!direct_map_address(&example, PMM_PAGE_SIZE, &result));
    example.revision = 0;
    example.offset = 0;
    CHECK(!direct_map_address(&example, PMM_PAGE_SIZE, &result));
    example.offset = UINT64_C(0xffff800000000001);
    CHECK(!direct_map_address(&example, PMM_PAGE_SIZE, &result));
    example.offset = UINT64_MAX - (PMM_PAGE_SIZE - 1);
    CHECK(!direct_map_address(&example, PMM_PAGE_SIZE, &result));
    CHECK(direct_map_address(&example, 0, &result) && result == example.offset);
    example.offset = UINT64_C(0xffff800000000000);
    CHECK(!direct_map_address(&example, 1, &result));
    CHECK(!direct_map_address(&example, PMM_LIMIT, &result));
    CHECK(direct_map_address(&example, PMM_PAGE_SIZE, &result) &&
          result == example.offset + PMM_PAGE_SIZE);
    CHECK(direct_map_address(&example, PMM_LIMIT - PMM_PAGE_SIZE, &result) &&
          result == example.offset + PMM_LIMIT - PMM_PAGE_SIZE);
    CHECK(serial_write("PASS: direct-map arithmetic checks\r\n"));

    CHECK(!direct_map_page(&pool, PMM_PAGE_SIZE));
    CHECK(!direct_map_page(0, PMM_PAGE_SIZE));
    CHECK(pmm_init(&pool, memory_map_get()) && pool.free >= 2);
    const uint64_t before = pool.free;
    uint64_t first, second;
    CHECK(pmm_alloc(&pool, &first) && pmm_alloc(&pool, &second) && first != second);
    CHECK(pmm_is_allocated(&pool, first) && pmm_is_allocated(&pool, second));
    CHECK(!direct_map_page(&pool, 0) && !direct_map_page(&pool, first + 1));
    CHECK(!direct_map_page(&pool, PMM_LIMIT));
    volatile uint8_t *a = direct_map_page(&pool, first);
    volatile uint8_t *b = direct_map_page(&pool, second);
    CHECK(a && b && a != b);
    /* Separate writes and reads, distinct page patterns, every byte including edges.
     * Volatile forces actual loads/stores; it does not flush caches or imply locking. */
    for (unsigned pass = 0; pass < 2; ++pass) {
        for (unsigned i = 0; i < PMM_PAGE_SIZE; ++i) {
            a[i] = (uint8_t)(i ^ (pass ? 0xaa : 0x55));
            b[i] = (uint8_t)(i ^ (pass ? 0x55 : 0xaa));
        }
        for (unsigned i = 0; i < PMM_PAGE_SIZE; ++i) {
            CHECK(a[i] == (uint8_t)(i ^ (pass ? 0xaa : 0x55)));
            CHECK(b[i] == (uint8_t)(i ^ (pass ? 0x55 : 0xaa)));
        }
    }
    CHECK(serial_write("PASS: two allocated pages retained distinct byte patterns\r\n"));
    CHECK(pmm_free(&pool, first) && !pmm_is_allocated(&pool, first));
    CHECK(!direct_map_page(&pool, first));
    CHECK(pmm_free(&pool, second) && !direct_map_page(&pool, second));
    /* Never use a or b again: free invalidated our ownership, not the CPU mapping. */
    CHECK(pool.free == before);
    return serial_write("PASS: direct-map tests completed; pages returned\r\n");
}
