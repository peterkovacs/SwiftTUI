// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ToDoList",
    platforms: [
      .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../../")
    ],
    targets: [
        .executableTarget(
            name: "ToDoList",
            dependencies: ["SwiftTUI"]),
        .testTarget(
            name: "ToDoListTests",
            dependencies: ["ToDoList"]),
    ]
)
