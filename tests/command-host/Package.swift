// swift-tools-version:6.3
import PackageDescription
import Foundation

let source = ProcessInfo.processInfo.environment["WASMKIT_SOURCE"]!
let package = Package(
    name: "CommandHost",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: source)],
    targets: [
        .target(name: "WasmKitCommand", dependencies: [
            .product(name: "WasmKit", package: "WasmKit"),
            .product(name: "WasmKitWASI", package: "WasmKit"),
            .product(name: "WASI", package: "WasmKit"),
            .product(name: "WAT", package: "WasmKit"),
        ], swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "Runner", dependencies: ["WasmKitCommand"]),
    ]
)
