// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RoomyCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RoomyCore", targets: ["RoomyCore"])
    ],
    targets: [
        .target(name: "RoomyCore"),
        .testTarget(name: "RoomyCoreTests", dependencies: ["RoomyCore"])
    ]
)
