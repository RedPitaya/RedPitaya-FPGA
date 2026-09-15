#ifndef REF_H
#define REF_H
typedef struct {
    const char *name;
    const unsigned long *actual;
    const unsigned long *expected;
    unsigned words;
} ref_table_t;
extern const ref_table_t ref_tables[];
extern const unsigned ref_tables_len;
#endif
