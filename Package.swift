// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HaierAC",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "HaierACCore"),
        .executableTarget(name: "HaierACApp", dependencies: ["HaierACCore"]),
        // 测试源码放在 Sources/HaierACCoreTests/（SwiftPM 默认查 Tests/，故显式指定 path）
        .testTarget(name: "HaierACCoreTests", dependencies: ["HaierACCore"], path: "Sources/HaierACCoreTests"),
    ]
)
