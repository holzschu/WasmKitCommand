#!/usr/bin/env bash
set -euo pipefail
# Usage: tests/tty-bridge.sh OWN_OUTPUT_DIR
# WASMKIT_COMMAND_SWIFT overrides the command source (to run the guest against a build without the imports).
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root=$(dirname "$here")
out=${1:?own output directory required}
source=${WASMKIT_COMMAND_SWIFT:-$root/WasmKitCommand.swift}
mkdir -p "$out/host/Sources/WasmKitCommand"
cp "$here/command-host/Package.swift" "$here/command-host/Package.resolved" "$out/host/"
cp -R "$here/command-host/Sources/Runner" "$out/host/Sources/"
cp "$source" "$out/host/Sources/WasmKitCommand/WasmKitCommand.swift"
shim="$here/command-host/Sources/ios_system"
xcrun clang -mmacosx-version-min=15.0 -c -fobjc-arc "$shim/streams.m" -I "$shim/include" -o "$out/streams.o"
# Any wasm32-wasip1 C compiler works; Zig is one that needs no sysroot. Zig's default
# 16 MiB initial memory is too much for a-Shell's ~35 MiB extension workers, hence the explicit limits.
uvx --from ziglang python -m ziglang cc -target wasm32-wasi -O2 -Wl,-z,stack-size=65536 \
	-Wl,--initial-memory=1048576 -Wl,--max-memory=16777216 "$here/tty-bridge/tty.c" -o "$out/tty.wasm"
WASMKIT_SOURCE="$root/WasmKit" nice -n 15 swift build \
	--package-path "$out/host" --scratch-path "$out/host-build" -j 2 \
	--force-resolved-versions \
	-Xswiftc -I -Xswiftc "$shim/include" -Xlinker "$out/streams.o" >"$out/host-build.log" 2>&1
"$here/tty-bridge/drive.py" "$out/host-build/debug/Runner" "$out/tty.wasm"
