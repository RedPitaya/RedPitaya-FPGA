/* Single-FSBL entry point: pick the DDR configuration before ps7_init() runs.
 *
 * Linked with -Wl,--wrap=ps7_init, so main()'s call lands here instead. The
 * generated ps7_init.c and main.c stay untouched.
 */
#include "rp_ddr_patch.h"

extern int __real_ps7_init(void);

int __wrap_ps7_init(void)
{
    if (rp_hw_rev_is_1gb()) {
        /* A rejected patch leaves the stock 512 MB tables in place, so the
         * board still boots - with half its memory rather than not at all. */
        (void)rp_ddr_patch_apply();
    }
    return __real_ps7_init();
}
