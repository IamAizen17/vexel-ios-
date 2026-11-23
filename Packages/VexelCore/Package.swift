// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VexelCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "VexelCore", targets: ["VexelCore"])
    ],
    targets: [
        .target(name: "VexelCore"),
        .testTarget(name: "VexelCoreTests", dependencies: ["VexelCore"])
    ]
)
