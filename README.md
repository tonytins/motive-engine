# 🏘️ Motives Engine

The Motives Engine provides the framework for creating characters with needs, aspirations, and interacting with simulated world.

## 📐 Design

I am designing this as an *extremely* modular framework around the idea of being easily unit testable and render-agnostic as possible. All the engine ever does is pass information back downstream to the frontend.

The Motives Engine is made up of three independent subsystems: Needs, Buffs and Aspirations. Only the Sim is aware of any of these. If freewill turned on, they will always search for something to do. 

A Sim "sees" their world through a radar system that occasionally pings their surroundings. Internally, this is known ``Broadcaster``. Every item in the world sends back what their offer and the Sim narrows in what matters most (whatever is below a certain threshold). Generally speaking, a Sim favours social and fun even if those motives are already maxed.

Items can statically full fill needs or a virtual machine (VM) built on top of the broadcasting architecture allows scripting based around varies states. Although dependent on the above architecture, the VM itself is just as independent as everything else. Modifying it will no doubt affect every script dependent on it but not the engine as a whole.

Unfortunately, the Aspirations (Wants/Fears) remains a bit of loose thread at this point.

In theory, it should be possible run this from the terminal using nothing but an ASCII interface and emojis to represent varies items and characters.

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
