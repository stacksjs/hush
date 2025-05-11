// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "Hush",
    platforms: [
        .macOS(.v15)
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
            path: "Hush.app/HushLib"),
        .testTarget(
            name: "HushTests",
            dependencies: ["HushLib"],
            path: "Hush.app/HushTests",
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