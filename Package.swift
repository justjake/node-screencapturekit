// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "node-screencapturekit",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(
            name: "NodeScreenCaptureKit",
            targets: ["NodeScreenCaptureKit"]
        ),
        .library(
            name: "Module",
            type: .dynamic,
            targets: ["NodeScreenCaptureKit"]
        )
    ],
    dependencies: [
        .package(path: "node_modules/node-swift")
    ],
    targets: [
        .target(
            name: "NodeScreenCaptureKit",
            dependencies: [
                .product(name: "NodeAPI", package: "node-swift"),
                .product(name: "NodeModuleSupport", package: "node-swift"),
            ]
        )
    ]
)
