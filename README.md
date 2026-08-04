# Motives Engine

Motive Engine provides the framework for creating characters with needs, aspirations, and interacting with simulated world.

## 🏗️ Architecture

I am designing this framework around the idea of being easily unit testable and render-agnostic as possible. All the engine ever does is pass information back downstream to the frontend.

In theory, it should be possible run this from the terminal using nothing ASCII interface and emojis to represent varies items.

## 📝 Goals

- [ ] [Scripting](./MotiveEngine/VM/README)
	- [ ] AST
	- [ ] Lexer
	- [ ] IR
	- [ ] Bindings
- [ ] Items
- [ ] Motives
- [ ] Aspirations (SWAF)
- [x] Buffs
- [ ] Sim
- [ ] Lot


## 📦 Installation

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

## ✅ Supported Versions

| swift-cst    | Minimum Swift Version |
| ------- | --------------------- |
| ``main`` | 6.3                   |

## ⚖️ License

I license this project under BSD-3-Clause license — see the [LICENSE](LICENSE) file for full text.
