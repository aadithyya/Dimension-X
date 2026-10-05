// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DimensionX",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DMXModel", targets: ["DMXModel"]),
        .library(name: "DMXProtocol", targets: ["DMXProtocol"]),
        .library(name: "DMXInspectKit", targets: ["DMXInspectKit"]),
        .library(name: "DMXCore", targets: ["DMXCore"]),
        .executable(name: "dmx-core", targets: ["dmx-core"]),
        .executable(name: "dmx-worker", targets: ["dmx-worker"]),
        .executable(name: "dmx-inspect", targets: ["dmx-inspect"]),
        .executable(name: "DimensionX", targets: ["DimensionX"]),
        .executable(name: "dmx-test-runner", targets: ["dmx-test-runner"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0")
    ],
    targets: [
        // Pure domain model
        .target(
            name: "DMXModel",
            dependencies: []
        ),
        // Protocol framing and message types
        .target(
            name: "DMXProtocol",
            dependencies: ["DMXModel"]
        ),
        // PE inspection engine
        .target(
            name: "DMXInspectKit",
            dependencies: ["DMXModel"]
        ),
        // Core application services library
        .target(
            name: "DMXCore",
            dependencies: [
                "DMXModel",
                "DMXProtocol",
                "DMXInspectKit",
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        // Executable targets
        .executableTarget(
            name: "dmx-core",
            dependencies: ["DMXCore"]
        ),
        .executableTarget(
            name: "dmx-worker",
            dependencies: ["DMXModel", "DMXProtocol"]
        ),
        .executableTarget(
            name: "dmx-inspect",
            dependencies: ["DMXModel", "DMXProtocol", "DMXInspectKit"]
        ),
        .executableTarget(
            name: "DimensionX",
            dependencies: ["DMXModel", "DMXProtocol"]
        ),
        .executableTarget(
            name: "dmx-test-runner",
            dependencies: ["DMXModel", "DMXProtocol", "DMXInspectKit", "DMXCore"]
        ),
        // Test targets
        .testTarget(
            name: "DMXModelTests",
            dependencies: ["DMXModel"]
        ),
        .testTarget(
            name: "DMXProtocolTests",
            dependencies: ["DMXProtocol"]
        ),
        .testTarget(
            name: "DMXInspectKitTests",
            dependencies: ["DMXInspectKit"]
        ),
        .testTarget(
            name: "DMXCoreTests",
            dependencies: ["DMXCore"]
        )
    ]
)
