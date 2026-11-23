// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VexelArchive",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "VexelArchive", targets: ["VexelArchive"])],
    dependencies: [.package(path: "../VexelCore")],
    targets: [.target(name: "VexelArchive", dependencies: ["VexelCore"])]
)
