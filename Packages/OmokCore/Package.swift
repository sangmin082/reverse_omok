// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OmokCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "OmokCore", targets: ["OmokCore"]),
    ],
    targets: [
        .target(name: "OmokCore"),
        .testTarget(name: "OmokCoreTests", dependencies: ["OmokCore"]),
    ]
)
