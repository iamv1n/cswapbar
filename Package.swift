// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CSwapBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CSwapBar", targets: ["CSwapBar"]),
        .library(name: "CSwapBarCore", targets: ["CSwapBarCore"]),
    ],
    targets: [
        // UI-free logic: CSwap integration, domain models, switching, privacy.
        .target(
            name: "CSwapBarCore",
            path: "Sources/CSwapBarCore"
        ),
        // The SwiftUI menu-bar app.
        .executableTarget(
            name: "CSwapBar",
            dependencies: ["CSwapBarCore"],
            path: "Sources/CSwapBarApp"
        ),
        .testTarget(
            name: "CSwapBarCoreTests",
            dependencies: ["CSwapBarCore"],
            path: "Tests/CSwapBarCoreTests"
        ),
    ]
)
