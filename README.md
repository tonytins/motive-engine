# 🏘️ Motives Engine

The Motives Engine provides the framework for creating characters with needs, aspirations, and interacting with simulated world.

## 📝 Goals

- [x] Motives: decay, fulfillment, and urgency
- [x] Items: reusable definitions, interaction offers, eligibility, and capacity
- [x] Autonomy and actions: scoring, player commands, and action execution
- [x] Sims, households, and lots: validated world state, routing, and a
  deterministic simulation session
- [x] Buffs: rules, ambient items, and timed buffs
- [x] [Scripting](./Sources/MotiveEngine/VM/README.md)
	- [x] AST
	- [x] Lexer
	- [x] IR
	- [x] Bindings
	- [x] Item interaction boundary
	- [x] Run interaction scripts in the simulation session
- [x] Wants and fears (SWAF), as an optional product
	- [x] The Sims 2-style wants and fears
	- [x] The Sims 3-style wishes
	- [ ] Targeted and lifetime wants

See the [roadmap](./docs/ROADMAP.md) for details.


## 📦 Installation

```swift
let package = Package(
    // name, platforms, products, etc.
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/tonytins/motive-engine.git", branch: "main"),
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

Wants and fears are optional. To use them, also add
`.product(name: "MotiveEngineSWAF", package: "motive-engine")` and
`import MotiveEngineSWAF`.

## 🏠 Example

`Examples/NewbieHouse` runs Bob and Betty Newbie through a short simulation on
the lot in its bundled `lot.json`, printing events, a map, and motive levels as
time advances:

```sh
swift run NewbieHouse              # bundled lot
swift run NewbieHouse path/to/lot.json
```

Ambient items, such as the Stereo, buff nearby Sims. Lot fields the engine
does not simulate yet, such as `relationship`, are ignored.

## 📚 Documentation

Start at [`docs/`](./docs/README.md) for the public documentation index and
the proposed engine architecture. See the [contributor guide](./docs/contributing.md)
for development workflow and the [engineering scorecard](./docs/scorecard.md)
for performance budgets and regression coverage floors.

## ✅ Supported Versions

| motive-engine    | Minimum Swift Version |
| ------- | --------------------- |
| ``main`` | 6.3                   |

## ⚖️ License

I license this project under BSD-3-Clause license — see the [LICENSE](LICENSE) file for full text.
