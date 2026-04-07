/*
 * genesis_stubs.c – Provides extern definitions for libretro-common inline
 * functions that are referenced as external symbols from libgenesis.a.
 *
 * The STATIC_LINKING build of Genesis Plus GX references string_is_empty as
 * an extern, but the header declares it as static INLINE. This separate
 * translation unit provides a concrete definition without conflicting with
 * the inline version in other .c files.
 */

#include <stdbool.h>

bool string_is_empty(const char *data) {
    return !data || *data == '\0';
}
