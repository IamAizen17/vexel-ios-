// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VexelRenderer",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "VexelRenderer", targets: ["VexelRenderer"])],
    dependencies: [.package(path: "../VexelCore")],
    targets: [
        .target(name: "VexelRenderer", dependencies: ["VexelCore"]),
        .testTarget(name: "VexelRendererTests", dependencies: ["VexelRenderer"])
    ]
)
