# Contributing

Thanks for your interest in Motive Engine! It's a Swift library for
needs-driven life simulation, built to be reused by many games and to run
without any particular renderer. This guide covers how to get set up, how
the project is organized, and what makes a change easy to accept.

If you want to make content for a game built on the engine, such as items,
interactions, or scripts, you want the [modding guide](./modding.md)
instead.

## Ways to help

- **Report a bug.** Open an issue with what you expected, what happened, and
  the smallest code or content that shows it.
- **Improve the docs.** If something confused you, it will confuse someone
  else. Fixes to wording and examples are welcome.
- **Write code.** The [roadmap](./ROADMAP.md) lists what's done and what's
  planned. Unchecked items are good places to start. For anything larger
  than a bug fix, open an issue first so we can agree on the approach before
  you spend time on it.

## Getting set up

You need Swift 6.3 or later on macOS or Linux. From the repository root:

```sh
swift build        # build everything
swift test         # run every test suite
swift run NewbieHouse                            # run the example
swift run -c release MotiveEngineBenchmarks      # check performance budgets
```

Continuous integration builds the package and runs the tests on macOS for
every push and pull request to `main`.

## How the project is organized

| Path | What's there |
| --- | --- |
| `Sources/MotiveEngine/` | The core library: motives, items, interactions, free will, actions, buffs, the simulation session, and content packs. |
| `Sources/MotiveEngine/VM/` | Robusta, the scripting language: lexer, parser, compiler, and runtime. |
| `Sources/MotiveEngineSWAF/` | Wants and fears, an optional library that builds only on the core's public API. |
| `Tests/` | Swift Testing suites for each library. |
| `Examples/NewbieHouse/` | A small program that runs two Sims on a sample lot. |
| `Benchmarks/` | Performance checks for the workloads in the [scorecard](./scorecard.md). |
| `schema/` | JSON schemas for content files. |
| `docs/` | Architecture, roadmap, modding, and this guide. |

The [architecture overview](./architecture.md) explains how the pieces fit
together. It's worth skimming before a larger change.

## What we look for in a change

These principles keep the engine dependable for every game that uses it.

- **It never crashes on bad input.** Game content and caller values can be
  wrong. Validate them where they enter the engine and report problems with
  a thrown error or a result value. Avoid force unwraps, `try!`, `fatalError`,
  and quietly substituting a default for invalid data.
- **It's deterministic.** The same inputs always produce the same results.
  When items could tie, sort them by a stable ID.
- **It stays render-agnostic.** The engine reports what happened; the game
  decides how to show it. Don't add UI, logging, or rendering concerns to the
  libraries.
- **Content and state stay separate.** Reusable definitions, such as an item
  type, are kept apart from instance state, such as one placed fridge.
  Eligibility, scoring, and running an action are separate steps.
- **Optional pieces stay optional.** Wants and fears, buffs, and scripts must
  never be required for a basic simulation to work.
- **Dependencies are rare.** Add one only when there's no reasonable way
  without it.

For code style, the project follows the
[Swift guidelines](../.agents/skills/swift-guidelines/SKILL.md) kept in this
repository: names that read clearly at the call site, documentation comments
on all public API, and flat control flow. When existing code and the
guidelines disagree, match the surrounding code.

## Tests

Every change needs tests that show the new behavior and its edge cases.

- Use Swift Testing (`import Testing`, `@Test`), not XCTest.
- Put tests next to the related suite in `Tests/MotiveEngineTests/` or
  `Tests/MotiveEngineSWAFTests/`.
- Test through the public API where possible, so tests catch what a game
  would see.
- Keep tests deterministic: no timing, randomness without a fixed seed, or
  dependence on test order.
- Use `@Test(arguments:)` when several cases share the same check.

The [scorecard](./scorecard.md) lists what each area must do, its status,
and the tests that prove it. If your change completes or affects a row,
update its status and evidence. If it touches a performance-sensitive area,
run the benchmarks before and after, and record real measurements
separately from target budgets.

## Documentation

If a change affects public API or behavior, update the docs in the same
pull request:

- [architecture.md](./architecture.md) for how systems work and fit together;
- [modding.md](./modding.md) for anything content authors can see;
- [ROADMAP.md](./ROADMAP.md) when a planned item is finished;
- [scorecard.md](./scorecard.md) for status, evidence, and performance changes.

Describe only what works today. Planned features belong in the roadmap, not
in the docs as if they already exist.

## Pull requests

Keep each pull request focused on one change, so it's easy to review. In the
description, include:

- the problem and how your change solves it;
- any change to public API or behavior, especially anything that could break
  existing games or mods;
- how you tested it;
- anything you deliberately left for later.

Before opening it, check that `swift build` and `swift test` pass.

## A note on AI assistants

The repository includes [AGENTS.md](../AGENTS.md), which gives AI coding
assistants the same expectations as this guide. You don't need to read it,
but if you use an assistant, it will pick those instructions up.
