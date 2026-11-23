// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VexelMedia",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "VexelMedia", targets: ["VexelMedia"])],
    dependencies: [.package(path: "../VexelCore")],
    targets: [.target(name: "VexelMedia", dependencies: ["VexelCore"])]
)
