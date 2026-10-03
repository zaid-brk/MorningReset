// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MorningResetCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "MorningResetCore", targets: ["MorningResetCore"])],
    targets: [
        .target(name: "MorningResetCore"),
        .testTarget(name: "MorningResetCoreTests", dependencies: ["MorningResetCore"])
    ]
)
