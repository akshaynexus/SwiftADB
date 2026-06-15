// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftADB",
    products: [
        .library(
            name: "SwiftADB",
            targets: ["SwiftADB"]
        ),
    ],
    targets: [
        .target(
            name: "CADB",
            path: "Sources/CADB",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("adb"),
                .linkedLibrary("c++"),
                .linkedLibrary("z"),
            ]
        ),
        .target(
            name: "SwiftADB",
            dependencies: ["CADB"]
        ),
        .testTarget(
            name: "SwiftADBTests",
            dependencies: ["SwiftADB"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
