// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "freewrite",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "freewrite",
            targets: ["freewrite"]),
    ],
    dependencies: [
        .package(url: "https://github.com/google/diff-match-patch", from: "1.0.0"),
        .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.2.5")
    ],
    targets: [
        .target(
            name: "freewrite",
            dependencies: ["diff-match-patch", "OpenAI"]),
        .testTarget(
            name: "freewriteTests",
            dependencies: ["freewrite"]),
    ]
) 