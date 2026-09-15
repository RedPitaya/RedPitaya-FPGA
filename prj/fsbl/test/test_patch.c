/* Host-side check: after rp_ddr_patch_apply() the 512 MB build's ps7 tables
 * must be word-for-word identical to the 1 GB build's. */
#include <stdio.h>
#include "ref.h"
#include "rp_ddr_patch.h"

int main(void)
{
    unsigned t, w, bad = 0, before = 0;

    for (t = 0; t < ref_tables_len; t++) {
        const ref_table_t *r = &ref_tables[t];
        for (w = 0; w < r->words; w++) {
            if (r->actual[w] != r->expected[w]) {
                before++;
                break;
            }
        }
    }
    printf("tables differing before patch: %u of %u\n", before, ref_tables_len);

    if (rp_ddr_patch_apply() != 0) {
        printf("FAIL: rp_ddr_patch_apply() rejected the tables\n");
        return 1;
    }

    for (t = 0; t < ref_tables_len; t++) {
        const ref_table_t *r = &ref_tables[t];
        for (w = 0; w < r->words; w++) {
            if (r->actual[w] != r->expected[w]) {
                printf("FAIL: %s word %u: 0x%lX != 0x%lX\n",
                       r->name, w, r->actual[w], r->expected[w]);
                bad++;
            }
        }
    }

    if (bad) {
        printf("FAIL: %u differing words after patch\n", bad);
        return 1;
    }
    printf("OK: all %u tables match the 1 GB build after patching\n",
           ref_tables_len);
    return 0;
}
