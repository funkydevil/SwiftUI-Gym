// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LiveCodeTrainer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LiveCodeTrainer", targets: ["LiveCodeTrainer"])
    ],
    targets: [
        .executableTarget(
            name: "LiveCodeTrainer",
            path: "Sources/LiveCodeTrainer"
        ),
        .testTarget(
            name: "LiveCodeTrainerTests",
            dependencies: ["LiveCodeTrainer"],
            path: "Tests/LiveCodeTrainerTests"
        )
    ]
)
