/* Single-FSBL DDR selection: turn the 512 MB DDR tables into the 1 GB ones.
 *
 * The FSBL is built for the 16-bit DDR bus (512 MB). On a board that carries
 * two DDR chips the generated ps7_ddr_init_data tables are patched in place,
 * before ps7_init() walks them, with the values taken from the 1 GB build.
 */
#ifndef RP_DDR_PATCH_H
#define RP_DDR_PATCH_H

typedef struct {
    unsigned offset;      /* word index of the EMIT_MASKWRITE in the table */
    unsigned long addr;
    unsigned long mask;
    unsigned long value;
} rp_ddr_patch_entry_t;

/* One generated ps7_ddr_init_data array and the delta that belongs to it.
 * ps7_init() selects an array by silicon revision at run time; every revision
 * is patched so the selection does not have to be duplicated here. */
typedef struct {
    unsigned long *table;
    const rp_ddr_patch_entry_t *entries;
    unsigned count;
} rp_ddr_patch_table_t;

extern const rp_ddr_patch_table_t rp_ddr_1gb_tables[];
extern const unsigned rp_ddr_1gb_tables_len;

/* Rewrites the MASKWRITE entries listed in the patch tables.
 * Returns 0 on success, -1 if any patched address was not found in its table,
 * which means the generated tables no longer match the generated patch. */
int rp_ddr_patch_apply(void);

/* Reads hw_rev from the board EEPROM over a bit-banged I2C0 and matches it
 * against the generated list of 1 GB models. Returns 1 only on a confident
 * match; any error falls back to 0 (512 MB), which is the stock behaviour. */
int rp_hw_rev_is_1gb(void);

#endif /* RP_DDR_PATCH_H */
