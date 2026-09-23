

import PackageDescription

let package = Package(
    name: "DimensionX",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DMXCore", targets: ["DMXCore"]),
        .executable(name: "dmx", targets: ["DMXCLI"]),
        .executable(name: "DimensionX", targets: ["DimensionX"]),
    ],
    targets: [
        .target(name: "DMXCore"),
        .executableTarget(
            name: "DMXCLI",
            dependencies: ["DMXCore"]
        ),
        .executableTarget(
            name: "DimensionX",
            dependencies: ["DMXCore"]
        ),
        .testTarget(
            name: "DMXCoreTests",
            dependencies: ["DMXCore"]
        ),
    ]
)
