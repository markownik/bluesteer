// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BlueSteerHostApp",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BlueSteerHost", targets: ["BlueSteerHost"]),
        .executable(name: "bluesteer", targets: ["bluesteer"]),
    ],
    dependencies: [
        .package(path: "../../packages/BlueSteerProtocol"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"),
    ],
    targets: [
        // Everything that is not UI: sessions, BLE, crypto glue, sockets.
        .target(
            name: "HostCore",
            dependencies: [
                .product(name: "BlueSteerProtocol", package: "BlueSteerProtocol"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
            ]
        ),
        // Menu-bar app. Wrapped into a .app bundle by tools/bundle-app.sh.
        .executableTarget(name: "BlueSteerHost", dependencies: ["HostCore"], resources: [.process("Resources")]),
        // The console remote: BLE central, remote end of the protocol, terminal attach.
        .target(name: "RemoteCore", dependencies: ["HostCore", .product(name: "BlueSteerProtocol", package: "BlueSteerProtocol")]),
        // Command line tool: `bluesteer run|hook|hooks|pair|hosts|connect`.
        .executableTarget(name: "bluesteer", dependencies: ["HostCore", "RemoteCore"]),
        .testTarget(name: "HostCoreTests", dependencies: ["HostCore", "RemoteCore"]),
    ]
)
