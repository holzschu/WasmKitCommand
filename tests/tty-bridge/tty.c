#include "../../include/ashell.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Modes: keys (read an arrow key, restore raw mode itself), leak (exit while raw),
   ctrlc (exit 130 on byte 0x03), trap (trap while raw). */
int main(int argc, char **argv) {
    const char *mode = argc > 1 ? argv[1] : "keys";
    uint32_t size[2] = {0, 0};
    if (ashell_tty_size(size) != 0) return 2;
    printf("SIZE %ux%u\n", size[0], size[1]);
    if (ashell_tty_raw(1) != 0) return 3;
    puts("RAW");
    fflush(stdout);

    unsigned char key[8];
    size_t used = 0;
    /* Unbuffered: a read returns what arrived, without waiting for a newline. */
    while (used < 3) {
        ssize_t count = read(STDIN_FILENO, key + used, sizeof(key) - used);
        if (count <= 0) return 4;
        used += (size_t)count;
        if (!strcmp(mode, "ctrlc") && key[0] == 0x03) {
            puts("CTRLC");
            fflush(stdout);
            return 130;
        }
        if (key[0] != 0x1b && strcmp(mode, "ctrlc")) return 5;
        if (!strcmp(mode, "ctrlc")) used = 0;
    }
    printf("KEY %02x %02x %02x\n", key[0], key[1], key[2]);
    fflush(stdout);
    if (!strcmp(mode, "trap")) __builtin_trap();
    if (!strcmp(mode, "leak")) return 0;
    if (ashell_tty_raw(0) != 0) return 6;
    puts("COOKED");
    return 0;
}
