# AGENTS.md: guide for AI agents and contributors

Motive Engine is a reusable, render-agnostic engine for needs-driven life
simulations in the style of The Sims, written in **Swift only** (Swift 6.3,
language mode 6) as a Swift package for macOS and Linux. It has **no
external dependencies**; don't add one without the owner's approval. Write
the name as **Motive Engine** in prose and docs; the modules and products
are `MotiveEngine` and `MotiveEngineSWAF`. The goal is one engine that games
from Sims 1-style to Sims 3-style can build on, with content that modders
can extend safely. The engine reports what happens; games decide how to
show it. Read this file first, then `docs/`.

## 1. Orientation (5 minutes)

| Read | Why |
|---|---|
| [docs/architecture.md](./docs/architecture.md) | How the systems work and fit together: motives, items, free will, actions, the session, buffs, scripts, content packs, script health, SWAF |
| [docs/ROADMAP.md](./docs/ROADMAP.md) | Stage and alpha gate, **current focus**, milestones with estimates, ranked work, risks |
| [docs/scorecard.md](./docs/scorecard.md) | Performance budgets and measurements, per-area status with the evidence for every row, known issues |
| [docs/contributing.md](./docs/contributing.md) | Setup, project layout, principles, tests, docs, pull requests |
| [docs/modding.md](./docs/modding.md) | The content-pack format as modders see it; keep it true when formats change |
| [Sources/MotiveEngine/VM/README.md](./Sources/MotiveEngine/VM/README.md) | The Robusta language and its host boundary |
| [.agents/skills/swift-guidelines/SKILL.md](./.agents/skills/swift-guidelines/SKILL.md) | Swift style: naming, documentation, control flow, extensions, tests |
| `schema/` | JSON schemas for content files, with examples decoded by tests |

## 2. Workspace map

```text
Sources/
  MotiveEngine/              the core library
    Motives Items Interactions Autonomy Actions
                             needs, content, eligibility, free will, action execution
    World Lot SimulationSession SimulationPhases SimulationResults
                             validated world state, routing, the step loop, events
    Buffs                    rule-based and timed passive effects
    InteractionScripts       the typed boundary between Robusta and interactions
    Content/                 content packs, composition, script health
    VM/                      Robusta: lexer, parser, IR, runtime
  MotiveEngineSWAF/          optional wants and fears
Tests/
  MotiveEngineTests/         core suites (Swift Testing)
  MotiveEngineSWAFTests/     SWAF suites
Examples/NewbieHouse/        runnable example: two Sims on a lot from lot.json
Benchmarks/                  performance budgets (see the scorecard)
schema/                      content-file JSON schemas
docs/                        architecture, roadmap, scorecard, guides
Stash/                       reference material only; never an implementation contract
```

**Boundaries are enforced by targets and by convention.**
- `MotiveEngineSWAF` is a separate target that depends only on the public API
  of `MotiveEngine`, so the compiler enforces that boundary. Never make core
  code depend on SWAF, and never widen core access just for SWAF.
- `VM/` knows nothing about the simulation: no motives, items, Sims, or
  sessions. Engine integration belongs in `InteractionScripts.swift` and the
  session, not in the VM.
- File access is confined to `DirectoryContentSource`. Everything else works
  on values or on the `ContentSource` protocol.

## 3. Golden rules

### Never crash (outranks feature work)

Games build on the engine and players load mods into it. Malformed content,
a bad command, a broken script, or an odd save must produce an error the
game can act on, never a trap. Don't ship a feature by adding a crash path;
fix a crash before building on top of it.

- **Library code never traps.** No force unwraps (`!`), `try!`, `as!`,
  implicitly unwrapped optionals, `fatalError`, `precondition`,
  `preconditionFailure`, or `assert`-based control flow in `Sources/`.
  Throw a typed error and propagate it with `try`; use `guard let … else
  { throw … }`. Unfinished features throw rather than trap.
- **No silent fallbacks for bad content.** A default is fine when the input
  is valid and the default is the documented meaning. Invalid content is
  reported, never quietly replaced.
- **Input-derived numbers are hostile.** Check `isFinite` for every `Double`
  that comes from content, callers, or arithmetic on them. Guard division by
  zero. Use `addingReportingOverflow` or clamp for counts that can grow.
  Check indices with `indices.contains` before subscripting.
- **Bound loops and recursion** that content can drive. Robusta has an
  instruction limit and a call-depth limit; new interpreters, graph walks,
  and searches need their own bounds or seen-sets.
- **Failures change nothing.** A throwing `step` leaves the session as it
  was. Build the next state in locals and commit it only at the end.
- **Contain content failures.** A failing script fails one action and feeds
  script health; it never stops a step. Follow that pattern for any new
  content-driven behavior.
- **Prove it.** Every crash or bad-input fix comes with a small regression
  test that failed before the fix.
- **Checked by hand for now.** Until a lint runs in CI (scorecard REL-6),
  run the search in [section 5](#5-before-you-finish-a-task) before
  finishing.

### Engine rules

1. **Render-agnostic.** No UI, rendering, logging, or printing in the
   libraries. Report what happened through typed events and results.
2. **Deterministic.** The same inputs always give the same results. Process
   entities in stable-ID order, break ties by stable IDs, take randomness
   only from a stored seed, and never read the clock. Cooldowns and timers
   count down by a step's elapsed time.
3. **Values, not objects.** Model state as `Sendable` structs and enums,
   and logic as pure systems (`MotiveSystem`, `BuffSystem`,
   `AspirationSystem`). `SimulationSession` is the only coordinator, and it
   doesn't own concurrency.
4. **Keep concepts separate.** Reusable definitions apart from instance
   state; eligibility, scoring, and execution as separate steps; advertised
   benefits apart from applied effects.
5. **Optional stays optional.** Buffs, scripts, content packs, and SWAF must
   never be required for a basic simulation, and their absence must leave
   behavior unchanged (see `OptionalExtensionTests.swift`).
6. **Every stable ID is a `StringIdentifier`.** New ID types conform to it
   instead of repeating validation and coding.
7. **Tests are the gate.** Swift Testing (`import Testing`, `@Test`), never
   XCTest. Test through the public API where possible, keep tests
   deterministic, and use `@Test(arguments:)` for shared checks.
8. **Public API is documented, and breaking changes are said out loud.**
   Every public declaration gets a documentation comment. A new case in a
   public enum, such as `SimulationEvent`, `SimulationCommand`, or a failure
   reason, breaks exhaustive `switch`es in games: update NewbieHouse and
   call it out in the change.
9. **Follow the [Swift guidelines](./.agents/skills/swift-guidelines/SKILL.md)**,
   and match the surrounding code when they disagree.
10. **Measure before optimizing.** Benchmark first, and record measurements
    separately from budgets.

## 4. Picking work

Priorities: whatever blocks the next stage first, then small items that
close scorecard rows, then the long tail.

0. **Read [docs/ROADMAP.md](./docs/ROADMAP.md):** the alpha gate, **Current
   focus**, and the ranked work. Unchecked items are plans, not available
   behavior. Scope decisions marked for the owner are not yours to make; ask.
1. **Check [docs/scorecard.md](./docs/scorecard.md):** each area's `missing`
   and `partial` rows, performance scenarios that are not benchmarked yet,
   and open known issues. Its statuses are verified; prefer them to
   estimates.
2. **Small, self-contained fixes** from the scorecard are good warm-ups: a
   missing regression test, a broken schema reference.

## 5. Before you finish a task

```sh
swift build                                     # every target: libraries, tests, example, benchmarks
swift test                                      # all suites
swift run NewbieHouse                           # if you touched the session, events, buffs, or content loading
swift run -c release MotiveEngineBenchmarks     # if you touched a benchmarked or hot path
grep -rnE 'try!|as!|fatalError|precondition|preconditionFailure' Sources   # must print nothing
```

Then bring the docs up to date in the same change:

- [docs/ROADMAP.md](./docs/ROADMAP.md): tick the checklist item, update the
  milestone row's done percentage and estimate, bump the status line, and
  add a revision-history row.
- [docs/scorecard.md](./docs/scorecard.md): flip the rows you moved, with
  their new evidence, and update the summary counts.
- [docs/architecture.md](./docs/architecture.md) for behavior, and
  [docs/modding.md](./docs/modding.md) plus `schema/` for anything content
  authors can see.

Describe only what works today. Sessions can end abruptly, so keep the tree
building and the tests green at every step; the roadmap's revision history
and the git log are how the next session picks up.

## 6. Parallel agents

- Use your own build directory to avoid SwiftPM's lock:
  `swift build --scratch-path .build/agent-<name>`, and the same flag for
  `swift test` and `swift run`. Delete it when you finish.
- Edit only the files you own. Shared files get small, surgical edits:
  `SimulationSession.swift`, `SimulationResults.swift`, `Package.swift`,
  `docs/ROADMAP.md`, and `docs/scorecard.md`. Re-read before editing.
- Put new systems in new files rather than growing a shared one.
- If someone else's in-progress edit breaks the build, wait and retry; don't
  fix their files.
- Keep `Package.swift` valid at all times; one broken manifest breaks
  everyone's build.

## 7. Where things are tracked

- [docs/ROADMAP.md](./docs/ROADMAP.md): stage, current focus, milestones,
  ranked work, and revision history.
- [docs/scorecard.md](./docs/scorecard.md): performance budgets and
  measurements, per-area status with evidence, and known issues.
- [docs/architecture.md](./docs/architecture.md): how the systems work.
- [docs/modding.md](./docs/modding.md) and `schema/`: the content formats.
- `Sources/` and `Tests/`: executable behavior and its regression tests.
- Git history: what changed and why.

Use issues and pull requests for discussion. Keep durable status in the
roadmap and scorecard, not in chat.

## 8. Keeping content formats complete

Content files are a public contract with modders.

- When the item decoder gains a field (`ItemContentFile.swift`), add it to
  `schema/pack-items.json`, its example, and [docs/modding.md](./docs/modding.md)
  in the same change. The same goes for `pack.json` and `swaf.json`.
- Optional new fields keep existing packs loading. A change that existing
  packs can't load is a new content `format`: raise
  `ContentPackManifest.supportedFormats` deliberately and say so.
- Every schema example must be decoded by a test.
- Content errors name the file at fault (`ContentPackError.invalidFile`), and
  no pack may read outside its own folder.
