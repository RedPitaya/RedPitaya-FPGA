/* Host-side checks for the u-boot environment parser. */
#include <stdio.h>
#include <string.h>

unsigned rp_env_hw_rev(const unsigned char *buf, unsigned len,
                       char *out, unsigned out_size);

static int failures;

static void check(const char *what, const char *blob, unsigned len,
                  const char *expect)
{
    char out[64];
    unsigned n;

    memset(out, 0, sizeof(out));
    n = rp_env_hw_rev((const unsigned char *)blob, len, out, sizeof(out));

    if (expect == NULL) {
        if (n != 0) {
            printf("FAIL %s: expected nothing, got '%s'\n", what, out);
            failures++;
            return;
        }
    } else if (n != strlen(expect) || strcmp(out, expect) != 0) {
        printf("FAIL %s: expected '%s', got '%s' (len %u)\n",
               what, expect, out, n);
        failures++;
        return;
    }
    printf("ok   %s\n", what);
}

#define BLOB(s) s, (unsigned)(sizeof(s) - 1)

int main(void)
{
    check("typical order",
          BLOB("hw_rev=STEM_250-12_v1.2\0serial=1234\0ethaddr=00:26:32:f0:00:01\0"),
          "stem_250-12_v1.2");

    check("hw_rev last",
          BLOB("serial=1234\0ethaddr=00:26:32:f0:00:01\0hw_rev=STEM_125-14_v1.1\0"),
          "stem_125-14_v1.1");

    check("already lower case",
          BLOB("hw_rev=stem_125-14_z7020_pro_v2.0\0"),
          "stem_125-14_z7020_pro_v2.0");

    check("absent", BLOB("serial=1234\0ethaddr=aa\0"), NULL);

    check("empty block", BLOB(""), NULL);

    check("blank eeprom", "\0\0\0\0", 4, NULL);

    check("empty value", BLOB("hw_rev=\0serial=1\0"), NULL);

    check("stops at end of environment",
          BLOB("serial=1\0\0hw_rev=STEM_250-12_v1.2\0"), NULL);

    check("prefix collision",
          BLOB("hw_rev_alt=nope\0hw_rev=STEM_250-12_120\0"),
          "stem_250-12_120");

    check("unterminated tail is still parsed",
          BLOB("hw_rev=STEM_250-12_v1.1"), "stem_250-12_v1.1");

    check("oversized value rejected",
          BLOB("hw_rev=0123456789012345678901234567890123456789012345678901234567890123456789\0"),
          NULL);

    if (failures) {
        printf("%d failing case(s)\n", failures);
        return 1;
    }
    printf("all env parser cases passed\n");
    return 0;
}
