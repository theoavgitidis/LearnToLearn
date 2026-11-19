// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LearnToLearn",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LearnToLearn", targets: ["LearnToLearn"])],
    targets: [
        .target(name: "LearnCore"),
        .executableTarget(name: "LearnToLearn", dependencies: ["LearnCore"]),
        .testTarget(name: "LearnCoreTests", dependencies: ["LearnCore"]),
        .testTarget(name: "AppIntegrationTests", dependencies: ["LearnToLearn", "LearnCore"])
    ]
)
