// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HaierAC",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "HaierACCore"),
        .executableTarget(name: "HaierACApp", dependencies: ["HaierACCore"]),
    ]
)
