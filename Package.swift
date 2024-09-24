// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftTUI",
    platforms: [
      .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftTUI",
            targets: ["SwiftTUI"]
        ),
    ],
    dependencies: [
         .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
         .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.13.0")
    ],
    targets: [
        .target(
            name: "SwiftTUI",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing")
            ]),
        .testTarget(
            name: "SwiftTUITests",
            dependencies: ["SwiftTUI"]),
    ]
)
