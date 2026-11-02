//
//  WasmKitCommand.swift
//  WasmKitCommand
//
//  Created by Nicolas Holzschuch on 02/07/2026.
//
internal import WasmKit
internal import WasmKitWASI
internal import WASI
internal import WAT
import Foundation
internal import SystemPackage
import ios_system

func convertCArguments(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> [String]? {
    
    var args = [String]()
    
    for i in 0..<Int(argc) {
        
        guard let argC = argv?[i] else {
            return nil
        }
        
        let arg = String(cString: argC)
        
        args.append(arg)
        
    }
    
    return args
}

// Host side of the ashell_v1 tty imports (include/ashell.h). Errors are negative WASI errno values.
final class TTYBridge {
    private var raw = false

    func link(to imports: inout Imports, store: Store) {
        imports.define(module: "ashell_v1", name: "tty_size",
                       Function(store: store, parameters: [.i32], results: [.i32]) { caller, args in
            [.i32(UInt32(bitPattern: self.size(caller: caller, pointer: args[0].i32)))]
        })
        imports.define(module: "ashell_v1", name: "tty_raw",
                       Function(store: store, parameters: [.i32], results: [.i32]) { _, args in
            [.i32(UInt32(bitPattern: self.setRaw(args[0].i32 != 0)))]
        })
    }

    private func size(caller: borrowing Caller, pointer: UInt32) -> Int32 {
        guard ios_isatty(fileno(thread_stdin)) != 0 else { return -59 }  // ENOTTY
        guard let memory = caller.instance?.exports[memory: "memory"],
              Int(pointer) + 8 <= memory.byteCount else { return -21 }   // EFAULT
        // a-Shell publishes the window size in the session environment.
        let columns = getenv("COLUMNS").flatMap { UInt32(String(cString: $0)) } ?? 80
        let rows = getenv("LINES").flatMap { UInt32(String(cString: $0)) } ?? 24
        memory.withUnsafeMutableBufferPointer(offset: UInt(pointer), count: 8) {
            $0.storeBytes(of: columns.littleEndian, as: UInt32.self)
            $0.storeBytes(of: rows.littleEndian, toByteOffset: 4, as: UInt32.self)
        }
        return 0
    }

    private func setRaw(_ enabled: Bool) -> Int32 {
        guard ios_isatty(fileno(thread_stdin)) != 0 else { return -59 }  // ENOTTY
        if enabled && !raw {
            ios_startInteractive()
        } else if !enabled && raw {
            ios_stopInteractive()
        }
        raw = enabled
        return 0
    }

    // Called when the program ends, whether by exit, Ctrl-C or a trap.
    func restore() {
        if raw { ios_stopInteractive() }
        raw = false
    }
}

@_cdecl("wasmkit")
public func wasmkit(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    guard let args = convertCArguments(argc: argc, argv: argv) else {
        fputs("Usage: wasmkit file.wasm\nExecutes webAssembly file.\n", thread_stdout)
        return 0
    }
    guard args.count > 1  else {
        fputs("Usage: wasmkit file.wasm\nExecutes webAssembly file.\n", thread_stdout)
        return -1
    }
    
    do {
        // Parse a WASI-compliant WebAssembly module from a file.
        let module = try parseWasm(filePath: String(args[1]))
        
        do {
            // Create a WASI instance forwarding to the host environment.
            var arguments = args
            arguments.removeFirst()
            if (arguments[0].hasSuffix(".wasm3")) {
                arguments[0].removeLast(".wasm3".count)
            }
            var environment : [String : String] = [:]
            if let localEnvironment = environmentAsArray() {
                for variable in localEnvironment {
                    if let envVar = variable as? String {
                        let components = envVar.components(separatedBy:"=")
                        if (components.count <= 1) {
                            continue
                        }
                        let name = components[0]
                        var value = envVar
                        if (value.count > name.count + 1) {
                            value.removeFirst(name.count + 1)
                        } else {
                            continue
                        }
                        environment[name] = value
                    }
                }
            }
            let currentDirectory = FileManager().currentDirectoryPath
            let tty = TTYBridge()
            defer { tty.restore() }
            let wasi = try WASIBridgeToHost(args: arguments,
                                            environment: environment,
                                            fileSystem: .host().withStdio(stdin:  fileno(thread_stdin),
                                                                          stdout:  fileno(thread_stdout),
                                                                          stderr:  fileno(thread_stderr))
                                                // Stdio is already mapped above. The extension sandbox denies
                                                // opening /dev itself; requiring it would abort even hello.
                                                .withPreopens([.init(guestPath: "/", hostPath: "/")])
            )
            // Start the WASI command-line application and close the bridge.
            let exitCode = try wasi.runAndClose { wasi in
                // Create engine and store
                let engine = Engine()
                let store = Store(engine: engine)
                // Instantiate a parsed module importing WASI
                var imports = Imports()
                wasi.link(to: &imports, store: store)
                tty.link(to: &imports, store: store)
                let instance = try module.instantiate(store: store, imports: imports)
                return try wasi.start(instance)
            }
            if (exitCode != 0) {
                // fputs("wasmkit: \(String(cString: strerror(Int32(exitCode))), default: "unknown error \(exitCode)")\n", thread_stdout)
            }
            // Exit the Swift program with the WASI exit code.
            return Int32(exitCode)
        }
        catch {
            fputs("wasmkit: unable to create the bridge to host: \(error), \(error.localizedDescription).\n", thread_stderr)
            return -1
        }
    }
    catch {
        fputs("wasmkit: unable to load and parse file \(args[1]): \(error)\n", thread_stderr)
        return -1
    }
}


