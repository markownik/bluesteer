// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "bluesteer-tools",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../packages/BlueSteerProtocol"),
        .package(path: "../apps/host"),
    ],
    targets: [
        .executableTarget(name: "pty-recorder"),
        .executableTarget(name: "term-bench", dependencies: [.product(name: "HostCore", package: "host")]),
        .executableTarget(name: "ble-bench-peripheral"),
        .executableTarget(name: "channel-probe", dependencies: [.product(name: "BlueSteerProtocol", package: "BlueSteerProtocol")]),
    ]
)
