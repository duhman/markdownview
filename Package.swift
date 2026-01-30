// swift-tools-version:6.1

import PackageDescription

let package = Package(
    name: "MarkdownView",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(
            name: "MarkdownView",
            targets: ["MarkdownViewApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MarkdownViewApp",
            path: "Sources"
        )
    ]
)
