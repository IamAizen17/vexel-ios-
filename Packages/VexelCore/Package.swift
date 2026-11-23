// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VexelCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "VexelCore", targets: ["VexelCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.21")
    ],
    targets: [
        .target(name: "VexelCore", dependencies: [
            .product(name: "ZIPFoundation", package: "ZIPFoundation")
        ]),
        .testTarget(name: "VexelCoreTests", dependencies: ["VexelCore", .product(name: "ZIPFoundation", package: "ZIPFoundation")])
    ]
)
