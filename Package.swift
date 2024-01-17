// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SQLiteAdapter",
    products: [
        .library(
            name: "SQLiteAdapter",
            targets: ["SQLiteAdapter"]),
    ],
    dependencies: [
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
