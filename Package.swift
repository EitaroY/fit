// swift-tools-version: 5.9
// This package exists so the pure core logic (Fit/Core) can be unit-tested
// with `swift test` alone. The app itself is built from Fit.xcodeproj, which
// compiles the same files directly into the app target.
import PackageDescription

let package = Package(
    name: "FitCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FitCore", targets: ["FitCore"])
    ],
    targets: [
        .target(name: "FitCore", path: "Fit/Core"),
        .testTarget(name: "FitCoreTests", dependencies: ["FitCore"], path: "Tests/FitCoreTests")
    ]
)
