// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Flags",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(name: "SwiftTUI", path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "Flags",
            dependencies: ["SwiftTUI"]),
        .testTarget(
            name: "FlagsTests",
            dependencies: ["Flags"]),
    ]
)
