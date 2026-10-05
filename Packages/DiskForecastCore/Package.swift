// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiskForecastCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DiskForecastCore", targets: ["DiskForecastCore"])
    ],
    targets: [
        .target(name: "DiskForecastCore"),
        .testTarget(name: "DiskForecastCoreTests", dependencies: ["DiskForecastCore"], resources: [.copy("Samples")])
    ]
)
