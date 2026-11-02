#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# ///
"""Run a guest under the built Runner on a pty and check the pty's own termios."""
import os, pty, sys, termios, time, select

RAW_BITS = termios.ICANON | termios.ECHO

def read_until(fd, needle, timeout=20):
    data, end = b"", time.time() + timeout
    while needle not in data:
        if time.time() > end:
            sys.exit(f"timeout waiting for {needle!r}, got {data!r}")
        if select.select([fd], [], [], 0.2)[0]:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            data += chunk
    return data

def lflags(slave):
    # The kernel sets PENDIN after a mode change; it is not a setting.
    return termios.tcgetattr(slave)[3] & ~termios.PENDIN

def run(runner, wasm, mode, keys, expect_status, expect_out):
    master, slave = pty.openpty()
    env = dict(os.environ, COLUMNS="100", LINES="40")
    pid = os.fork()
    if pid == 0:
        os.setsid()
        os.dup2(slave, 0); os.dup2(slave, 1); os.dup2(slave, 2)
        os.execve(runner, [runner, wasm, mode], env)
    cooked = lflags(slave)
    assert cooked & RAW_BITS == RAW_BITS, "pty must start in line mode"
    out = read_until(master, b"RAW\n")
    assert lflags(slave) & RAW_BITS == 0, f"{mode}: guest asked for raw but terminal is {lflags(slave):#x}"
    os.write(master, keys)
    out += read_until(master, expect_out)
    _, status = os.waitpid(pid, 0)
    code = os.waitstatus_to_exitcode(status)
    assert code == expect_status, f"{mode}: exit {code}, wanted {expect_status}; output {out!r}"
    assert b"SIZE 100x40\r\n" in out, f"{mode}: {out!r}"
    assert lflags(slave) == cooked, f"{mode}: terminal not restored ({lflags(slave):#x} vs {cooked:#x})"
    print(f"PASS {mode}: exit {code}, terminal restored")

def main():
    runner, wasm = sys.argv[1:3]
    run(runner, wasm, "keys", b"\x1b[A", 0, b"COOKED")
    run(runner, wasm, "leak", b"\x1b[B", 0, b"KEY 1b 5b 42")
    run(runner, wasm, "ctrlc", b"\x03", 130, b"CTRLC")
    # A wasm trap makes the runner fail; the terminal must still be restored.
    run(runner, wasm, "trap", b"\x1b[C", 255, b"KEY 1b 5b 43")

main()
