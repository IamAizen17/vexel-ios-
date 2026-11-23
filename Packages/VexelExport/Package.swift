// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VexelExport",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "VexelExport", targets: ["VexelExport"])],
    dependencies: [
        .package(path: "../VexelCore"),
        .package(path: "../VexelRenderer"),
        .package(path: "../VexelMedia"),
        .package(path: "../VexelAudio")
    ],
    targets: [.target(name: "VexelExport", dependencies: ["VexelCore", "VexelRenderer", "VexelMedia", "VexelAudio"])]
)
