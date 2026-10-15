// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MotiveEngine",
    platforms: [.macOS(.v10_15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MotiveEngine",
            targets: ["MotiveEngine"],
        ),
        .library(
            name: "MotiveEngineSWAF",
            targets: ["MotiveEngineSWAF"],
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MotiveEngine",
            exclude: [
                "VM/README.md",
            ],
        ),
        .target(
            name: "MotiveEngineSWAF",
            dependencies: ["MotiveEngine"],
        ),
        .testTarget(
            name: "MotiveEngineTests",
            dependencies: ["MotiveEngine"],
        ),
        .testTarget(
            name: "MotiveEngineSWAFTests",
            dependencies: ["MotiveEngine", "MotiveEngineSWAF"],
        ),
        .executableTarget(
            name: "MotiveEngineBenchmarks",
            dependencies: ["MotiveEngine"],
            path: "Benchmarks/MotiveEngineBenchmarks",
        ),
        .executableTarget(
            name: "NewbieHouse",
            dependencies: ["MotiveEngine"],
            path: "Examples/NewbieHouse",
            resources: [
                .copy("lot.json"),
                .copy("Content"),
            ],
        ),
    ],
    swiftLanguageModes: [.v6],
)
