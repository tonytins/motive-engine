# Motive Engine

Motive Engine is a life simulation engine for creating simulated characters with needs or wants and fears. 

You can simulate basic needs or wants and fears. The latter of which is based on a 

## Installation

```swift
let package = Package(
    // name, platforms, products, etc.
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/tonytins/motive-engine.git", branche: "main"),
    ],
    targets: [
        .executableTarget(name: "<your-game>", dependencies: [
            // other dependencies
            .product(name: "MotiveEngine", package: "motive-engine"),
        ]),
        // other targets
    ]
)
```

Or in Xcode: File -> Add Package Dependencies, then paste the repo URL.

## Supported Versions

| swift-cst    | Minimum Swift Version |
| ------- | --------------------- |
| ``main`` | 6.3                   |

## License

I license this project under BSD-3-Clause license — see the [LICENSE](LICENSE) file for full text.
