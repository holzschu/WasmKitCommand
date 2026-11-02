# WasmKit Command

This is a small repository, built around WasmKit, in order to create a framework that calls a "wasmkit" command.



## Terminal bridge

Programs that draw full-screen interfaces need the window size and direct key input, which WASI does not provide. The command links two imports from module `ashell_v1` (declared in `include/ashell.h`):

- `tty_size(uint32_t size[2])` writes columns and rows, read from `COLUMNS` and `LINES` (80x24 when unset). There is no resize event; poll it.
- `tty_raw(int32_t enabled)` switches direct keyboard input on or off. It is switched off when the program ends, by exit, Ctrl-C or a trap.

Both return a negative WASI errno on failure (`-59` when stdin is not a terminal). Test on macOS with Xcode and Swift 6.3 or newer:

```sh
bash tests/tty-bridge.sh /private/tmp/wasmkit-tty
```

It builds the command against a stand-in for `ios_system`, runs `tests/tty-bridge/tty.c` on a pty and checks the pty's terminal mode before, during and after each run.
