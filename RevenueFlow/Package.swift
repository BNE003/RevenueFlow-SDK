// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RevenueFlow",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RevenueFlow",
            targets: ["RevenueFlow"]),
    ],
    dependencies: [
        // Supabase Swift SDK for direct database access
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RevenueFlow",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ]),
        .testTarget(
            name: "RevenueFlowTests",
            dependencies: ["RevenueFlow"]
        ),
    ]
)
