// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftADB",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftADB",
            targets: ["SwiftADB"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.3.0"),
        .package(url: "https://github.com/apple/swift-asn1.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftADB",
            dependencies: [
                "BigInt",
                .product(name: "SwiftASN1", package: "swift-asn1")
            ]
        ),
        .testTarget(
            name: "SwiftADBTests",
            dependencies: ["SwiftADB"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
