#ifndef ASHELL_WASM_HOST_H
#define ASHELL_WASM_HOST_H

#include <stdint.h>

#if defined(__wasm__)
#define ASHELL_IMPORT(name) __attribute__((import_module("ashell_v1"), import_name(name)))
#else
#define ASHELL_IMPORT(name)
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Errors are negative WASI errno values: -21 (fault), -59 (notty). */

/* size[0] = columns; size[1] = rows. There is no resize event: poll this call. */
ASHELL_IMPORT("tty_size")
int32_t ashell_tty_size(uint32_t size[2]);
/* Nonzero reads keys directly from a-Shell without line editing; zero restores line mode.
   The host also restores line mode when the program ends, however it ends. */
ASHELL_IMPORT("tty_raw")
int32_t ashell_tty_raw(int32_t enabled);

#ifdef __cplusplus
}
#endif

#undef ASHELL_IMPORT
#endif
