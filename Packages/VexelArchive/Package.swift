// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VexelArchive",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "VexelArchive", targets: ["VexelArchive"])],
    dependencies: [
        .package(path: "../VexelCore"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.19")
    ],
    targets: [
        .target(name: "VexelArchive", dependencies: [
            .product(name: "VexelCore", package: "vexelcore"),
            .product(name: "ZIPFoundation", package: "ZIPFoundation")
        ]),
        .testTarget(name: "VexelArchiveTests", dependencies: ["VexelArchive", "VexelCore"])
    ]
)
