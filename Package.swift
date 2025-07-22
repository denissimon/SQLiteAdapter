// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SQLiteAdapter",
    platforms: [.iOS(.v12), .macOS(.v10_13), .tvOS(.v12), .watchOS(.v4)],
    products: [
        .library(
            name: "SQLiteAdapter",
            targets: ["SQLiteAdapter"]),
    ],
    targets: [
        .target(
            name: "SQLiteAdapter",
            path: "Sources"),
        .testTarget(
            name: "SQLiteAdapterTests",
            dependencies: ["SQLiteAdapter"],
            path: "Tests"),
    ]
)
