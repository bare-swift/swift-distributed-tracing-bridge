// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import PackageDescription

let package = Package(
    name: "swift-distributed-tracing-bridge",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "DistributedTracingBridge", targets: ["DistributedTracingBridge"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.0"),
        .package(url: "https://github.com/bare-swift/swift-bytes.git", from: "0.1.0"),
        .package(url: "https://github.com/bare-swift/swift-otlp-exporter.git", from: "0.1.0"),
        .package(url: "https://github.com/bare-swift/swift-tracing-otlp.git", from: "0.3.0"),
        .package(url: "https://github.com/apple/swift-distributed-tracing.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "DistributedTracingBridge",
            dependencies: [
                .product(name: "Bytes", package: "swift-bytes"),
                .product(name: "OTLPExporter", package: "swift-otlp-exporter"),
                .product(name: "TracingOTLP", package: "swift-tracing-otlp"),
                .product(name: "Tracing", package: "swift-distributed-tracing")
            ]
        ),
        .testTarget(
            name: "DistributedTracingBridgeTests",
            dependencies: ["DistributedTracingBridge"],
            resources: [.copy("../Vectors")]
        )
    ]
)
