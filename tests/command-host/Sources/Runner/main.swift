import WasmKitCommand
import ios_system
import Darwin

initializeStreams()
let arguments = (["wasmkit"] + CommandLine.arguments.dropFirst()).map { strdup($0) }
defer { arguments.forEach { free($0) } }
var argv = arguments + [nil]
let status = argv.withUnsafeMutableBufferPointer { wasmkit(argc: Int32(arguments.count), argv: $0.baseAddress) }
exit(status)
