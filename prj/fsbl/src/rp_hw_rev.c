/* Reads hw_rev from the board EEPROM before ps7_init() configures the PS.
 *
 * At this point the PLLs and peripheral clocks are still whatever the BootROM
 * left behind, so the I2C controller cannot be programmed to a known bit rate.
 * The two EEPROM lines (MIO 50/51) are therefore driven as GPIO and the
 * protocol is bit-banged: the only timing dependency is a delay loop, and a
 * slower CPU just means a slower bus.
 *
 * Every wait is bounded and every failure path returns "not a 1 GB board", so
 * a dead or blank EEPROM degrades to the stock 512 MB configuration instead of
 * hanging the boot.
 */
#include "rp_ddr_patch.h"

#if defined(__has_include)
#  if __has_include("rp_ram_profiles.h")
#    include "rp_ram_profiles.h"
#  endif
#endif

/* ------------------------------------------------------------------ SLCR -- */

#define SLCR_LOCK           0xF8000004u
#define SLCR_UNLOCK         0xF8000008u
#define SLCR_LOCKSTA        0xF800000Cu
#define SLCR_UNLOCK_KEY     0x0000DF0Du
#define SLCR_LOCK_KEY       0x0000767Bu

#define SLCR_GPIO_RST_CTRL  0xF800022Cu
#define SLCR_APER_CLK_CTRL  0xF800012Cu
#define APER_GPIO_CLKACT    (1u << 22)

#define SLCR_MIO_PIN(n)     (0xF8000700u + 4u * (n))

/* Bits [7:0] hold TRI_ENABLE and the L0..L3 mux selects. Clearing them selects
 * GPIO with the output buffer enabled; bits [13:8] (io type, pull-up, speed)
 * are left as the board configured them. */
#define MIO_MUX_MASK        0x000000FFu

/* ------------------------------------------------------------------ GPIO -- */

#define GPIO_DATA_1         0xE000A044u
#define GPIO_DATA_1_RO      0xE000A064u
#define GPIO_DIRM_1         0xE000A244u
#define GPIO_OEN_1          0xE000A248u

#define SCL_MIO             50u
#define SDA_MIO             51u
#define SCL_BIT             (1u << (SCL_MIO - 32u))
#define SDA_BIT             (1u << (SDA_MIO - 32u))

/* ---------------------------------------------------------------- EEPROM -- */

#define EEPROM_ADDR         0x50u   /* atmel,24c64 on i2c0 */
#define EEPROM_ENV_OFFSET   0x1800u /* u-boot environment block */
#define EEPROM_ENV_SIZE     0x0400u

/* Half a bit period. Sized so the bus stays under 100 kHz even with the CPU at
 * its maximum; a slower CPU only slows the transfer down. */
#define I2C_HALF_PERIOD_LOOPS 4000u

/* Upper bound for a line that refuses to rise (a stuck slave or no pull-up). */
#define I2C_STRETCH_LOOPS     100000u

#define HW_REV_MAX          64u

static volatile unsigned long *reg(unsigned long addr)
{
    return (volatile unsigned long *)addr;
}

static void rd_delay(void)
{
    volatile unsigned i;

    for (i = 0; i < I2C_HALF_PERIOD_LOOPS; i++) {
        __asm__ __volatile__("nop");
    }
}

/* ------------------------------------------------------------ bit-banging -- */

static void line_low(unsigned long bit)
{
    *reg(GPIO_DATA_1) &= ~bit;   /* drive 0 */
    *reg(GPIO_OEN_1) |= bit;     /* enable the output buffer */
}

static void line_release(unsigned long bit)
{
    *reg(GPIO_OEN_1) &= ~bit;    /* tri-state, the pull-up takes over */
}

static int line_read(unsigned long bit)
{
    return (*reg(GPIO_DATA_1_RO) & bit) ? 1 : 0;
}

/* Releases SCL and waits for it to actually rise, so a slave that stretches
 * the clock is honoured. Returns 0 if the line stayed low. */
static int scl_high(void)
{
    unsigned i;

    line_release(SCL_BIT);
    for (i = 0; i < I2C_STRETCH_LOOPS; i++) {
        if (line_read(SCL_BIT)) {
            rd_delay();
            return 1;
        }
    }
    return 0;
}

static void scl_low(void)
{
    line_low(SCL_BIT);
    rd_delay();
}

static int i2c_start(void)
{
    line_release(SDA_BIT);
    if (!scl_high()) {
        return 0;
    }
    line_low(SDA_BIT);
    rd_delay();
    scl_low();
    return 1;
}

static int i2c_stop(void)
{
    line_low(SDA_BIT);
    if (!scl_high()) {
        return 0;
    }
    line_release(SDA_BIT);
    rd_delay();
    return 1;
}

/* Returns 1 when the slave acknowledged. */
static int i2c_write_byte(unsigned char value)
{
    int bit, ack;

    for (bit = 7; bit >= 0; bit--) {
        if (value & (1u << bit)) {
            line_release(SDA_BIT);
        } else {
            line_low(SDA_BIT);
        }
        rd_delay();
        if (!scl_high()) {
            return 0;
        }
        scl_low();
    }

    line_release(SDA_BIT);
    rd_delay();
    if (!scl_high()) {
        return 0;
    }
    ack = !line_read(SDA_BIT);
    scl_low();
    return ack;
}

static int i2c_read_byte(int ack, unsigned char *out)
{
    unsigned value = 0;
    int bit;

    line_release(SDA_BIT);
    for (bit = 0; bit < 8; bit++) {
        rd_delay();
        if (!scl_high()) {
            return 0;
        }
        value = (value << 1) | (unsigned)line_read(SDA_BIT);
        scl_low();
    }

    if (ack) {
        line_low(SDA_BIT);
    } else {
        line_release(SDA_BIT);
    }
    rd_delay();
    if (!scl_high()) {
        return 0;
    }
    scl_low();
    line_release(SDA_BIT);

    *out = (unsigned char)value;
    return 1;
}

/* ------------------------------------------------------------- pin setup -- */

typedef struct {
    unsigned long mio_scl;
    unsigned long mio_sda;
    unsigned long dirm;
    unsigned long oen;
    unsigned long data;
    unsigned long lock_state;
} pin_state_t;

static void bus_claim(pin_state_t *saved)
{
    saved->lock_state = *reg(SLCR_LOCKSTA);
    *reg(SLCR_UNLOCK) = SLCR_UNLOCK_KEY;

    /* The GPIO block may still be gated or held in reset by the BootROM. */
    *reg(SLCR_APER_CLK_CTRL) |= APER_GPIO_CLKACT;
    *reg(SLCR_GPIO_RST_CTRL) = 0u;

    saved->mio_scl = *reg(SLCR_MIO_PIN(SCL_MIO));
    saved->mio_sda = *reg(SLCR_MIO_PIN(SDA_MIO));
    *reg(SLCR_MIO_PIN(SCL_MIO)) = saved->mio_scl & ~MIO_MUX_MASK;
    *reg(SLCR_MIO_PIN(SDA_MIO)) = saved->mio_sda & ~MIO_MUX_MASK;

    saved->dirm = *reg(GPIO_DIRM_1);
    saved->oen = *reg(GPIO_OEN_1);
    saved->data = *reg(GPIO_DATA_1);

    /* Open drain: the direction stays "output", the output enable is what
     * toggles between driving 0 and letting the pull-up win. */
    *reg(GPIO_DATA_1) &= ~(SCL_BIT | SDA_BIT);
    *reg(GPIO_OEN_1) &= ~(SCL_BIT | SDA_BIT);
    *reg(GPIO_DIRM_1) |= (SCL_BIT | SDA_BIT);
}

static void bus_release(const pin_state_t *saved)
{
    *reg(GPIO_OEN_1) = saved->oen;
    *reg(GPIO_DIRM_1) = saved->dirm;
    *reg(GPIO_DATA_1) = saved->data;

    *reg(SLCR_MIO_PIN(SCL_MIO)) = saved->mio_scl;
    *reg(SLCR_MIO_PIN(SDA_MIO)) = saved->mio_sda;

    if (saved->lock_state & 1u) {
        *reg(SLCR_LOCK) = SLCR_LOCK_KEY;
    }
}

/* Some masters leave the bus mid-transfer after a reset. Clock SDA free before
 * the first start condition. */
static void bus_recover(void)
{
    int i;

    line_release(SDA_BIT);
    for (i = 0; i < 9 && !line_read(SDA_BIT); i++) {
        scl_low();
        if (!scl_high()) {
            return;
        }
    }
    (void)i2c_stop();
}

/* ------------------------------------------------------------ env parsing -- */

static char to_lower(char c)
{
    return (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
}

/* Pulls the hw_rev value out of a u-boot environment block: NUL-separated
 * "key=value" entries terminated by an empty one. The value is lower-cased to
 * match the generated model list. Returns its length, or 0 when absent.
 * Kept free of hardware access so it can be tested on the host. */
unsigned rp_env_hw_rev(const unsigned char *buf, unsigned len,
                       char *out, unsigned out_size)
{
    static const char key[] = "hw_rev=";
    const unsigned key_len = (unsigned)(sizeof(key) - 1u);
    unsigned pos = 0;

    while (pos < len) {
        unsigned start = pos;
        unsigned entry_len;
        unsigned i;

        while (pos < len && buf[pos] != 0) {
            pos++;
        }
        entry_len = pos - start;
        pos++;  /* step over the NUL */

        if (entry_len == 0) {
            break;  /* empty entry: end of the environment */
        }
        if (entry_len <= key_len) {
            continue;
        }

        for (i = 0; i < key_len; i++) {
            if ((char)buf[start + i] != key[i]) {
                break;
            }
        }
        if (i != key_len) {
            continue;
        }

        {
            unsigned value_len = entry_len - key_len;

            if (value_len + 1u > out_size) {
                return 0;  /* implausible value, treat as unreadable */
            }
            for (i = 0; i < value_len; i++) {
                out[i] = to_lower((char)buf[start + key_len + i]);
            }
            out[value_len] = '\0';
            return value_len;
        }
    }
    return 0;
}

#if !defined(RP_HW_REV_HOST_TEST)

/* Streams the environment block out of the EEPROM, stopping early at the
 * double NUL that ends it. Returns the number of bytes stored. */
static unsigned read_env(unsigned char *buf, unsigned size)
{
    unsigned i;
    int prev_was_nul = 0;

    if (!i2c_start()) {
        return 0;
    }
    if (!i2c_write_byte((unsigned char)(EEPROM_ADDR << 1)) ||
        !i2c_write_byte((unsigned char)(EEPROM_ENV_OFFSET >> 8)) ||
        !i2c_write_byte((unsigned char)(EEPROM_ENV_OFFSET & 0xFFu)) ||
        !i2c_start() ||
        !i2c_write_byte((unsigned char)((EEPROM_ADDR << 1) | 1u))) {
        (void)i2c_stop();
        return 0;
    }

    for (i = 0; i < size; i++) {
        unsigned char b;

        if (!i2c_read_byte(i + 1u < size, &b)) {
            (void)i2c_stop();
            return 0;
        }
        buf[i] = b;

        if (b == 0) {
            if (prev_was_nul) {
                i++;
                break;
            }
            prev_was_nul = 1;
        } else {
            prev_was_nul = 0;
        }
    }

    (void)i2c_stop();
    return i;
}

#endif /* !RP_HW_REV_HOST_TEST */

/* ------------------------------------------------------------------- api -- */

#if !defined(RP_HW_REV_HOST_TEST)

int rp_hw_rev_is_1gb(void)
{
#if defined(RP_RAM_PROFILES_AVAILABLE)
    static unsigned char env[EEPROM_ENV_SIZE];
    pin_state_t saved;
    char hw_rev[HW_REV_MAX];
    unsigned len, env_len, i, j;

    bus_claim(&saved);
    bus_recover();
    env_len = read_env(env, sizeof(env));
    bus_release(&saved);

    len = rp_env_hw_rev(env, env_len, hw_rev, sizeof(hw_rev));
    if (len == 0) {
        return 0;
    }

    for (i = 0; i < RP_HW_REV_1GB_COUNT; i++) {
        const char *candidate = rp_hw_rev_1gb[i];

        for (j = 0; j <= len; j++) {
            if (candidate[j] != hw_rev[j]) {
                break;
            }
            if (hw_rev[j] == '\0') {
                return 1;
            }
        }
    }
    return 0;
#else
    /* Built without the generated model list: behave exactly as the stock
     * 512 MB FSBL. */
    return 0;
#endif
}

#endif /* !RP_HW_REV_HOST_TEST */
