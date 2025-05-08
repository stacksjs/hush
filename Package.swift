// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "Hush",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "HushLib",
            targets: ["HushLib"]),
    ],
    targets: [
        .target(
            name: "HushLib",
            dependencies: [],
            path: "Hush/HushLib"),
        .testTarget(
            name: "HushTests",
            dependencies: ["HushLib"],
            path: "Hush/HushTests",
            exclude: [
                "AppDelegateTests.swift",
                "DNDManagerTests.swift",
                "HushUITests.swift",
                "ScreenShareDetectorTests.swift",
                "ScreenSharingIntegrationTests.swift",
                "TestHelpers/ScreenShareSimulator.swift",
                "README.md"
            ])
    ]
) 