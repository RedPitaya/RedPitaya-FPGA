/* In-place patching of the generated ps7 init tables for a 1 GB board.
 *
 * The tables are plain arrays in .data and the FSBL runs from OCM, so they can
 * be rewritten before ps7_init() walks them. Only the value and mask words of
 * existing EMIT_MASKWRITE entries are touched - nothing is inserted or removed.
 */
#include "rp_ddr_patch.h"

#define OPCODE_MASKWRITE 3u

/* First word of an EMIT_MASKWRITE entry: opcode in the high nibble, argument
 * count in the low one. */
#define MASKWRITE_WORD0 (unsigned long)((OPCODE_MASKWRITE << 4) | 3u)

static int verify(void)
{
    unsigned t, i;

    for (t = 0; t < rp_ddr_1gb_tables_len; t++) {
        const rp_ddr_patch_table_t *tab = &rp_ddr_1gb_tables[t];

        for (i = 0; i < tab->count; i++) {
            const rp_ddr_patch_entry_t *e = &tab->entries[i];
            const unsigned long *slot = tab->table + e->offset;

            if (slot[0] != MASKWRITE_WORD0 || slot[1] != e->addr) {
                return -1;
            }
        }
    }
    return 0;
}

int rp_ddr_patch_apply(void)
{
    unsigned t, i;

    /* Check every offset before writing anything: a half-patched DDR
     * configuration would be worse than the stock 512 MB one. */
    if (verify() != 0) {
        return -1;
    }

    for (t = 0; t < rp_ddr_1gb_tables_len; t++) {
        const rp_ddr_patch_table_t *tab = &rp_ddr_1gb_tables[t];

        for (i = 0; i < tab->count; i++) {
            const rp_ddr_patch_entry_t *e = &tab->entries[i];
            unsigned long *slot = tab->table + e->offset;

            slot[2] = e->mask;
            slot[3] = e->value;
        }
    }
    return 0;
}
