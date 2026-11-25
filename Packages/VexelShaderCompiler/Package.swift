// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VexelShaderCompiler",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "VexelShaderCompiler", targets: ["VexelShaderCompiler"])],
    targets: [
        .target(name: "VexelShaderCompiler"),
        .testTarget(name: "VexelShaderCompilerTests", dependencies: ["VexelShaderCompiler"])
    ]
)
