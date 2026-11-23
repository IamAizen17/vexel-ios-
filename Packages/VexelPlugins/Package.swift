// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VexelPlugins",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "VexelPlugins", targets: ["VexelPlugins"])],
    dependencies: [
        .package(path: "../VexelCore"),
        .package(path: "../VexelArchive")
    ],
    targets: [.target(name: "VexelPlugins", dependencies: ["VexelCore", "VexelArchive"])]
)
