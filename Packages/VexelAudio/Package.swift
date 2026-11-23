// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VexelAudio",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "VexelAudio", targets: ["VexelAudio"])],
    dependencies: [.package(path: "../VexelCore")],
    targets: [.target(name: "VexelAudio", dependencies: ["VexelCore"])]
)
