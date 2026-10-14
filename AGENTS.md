# Motive Engine

Motive Engine is a Swift 6.3 package for reusable, render-agnostic life
simulation systems. Its current foundations include motives, item definitions,
interaction eligibility and scoring, action state, grid utilities, and the
independent Robusta scripting subsystem. It is still an evolving library, not
a complete simulation loop. Keep implementation, tests, and documentation
clear about what works today and what remains planned.

## 1. Orientation

| Read | Why |
| --- | --- |
| [README.md](./README.md) | Package purpose, installation, and supported Swift version. |
| [docs/README.md](./docs/README.md) | Public documentation index and documentation scope. |
| [docs/architecture.md](./docs/architecture.md) | Current foundations and proposed system boundaries. |
| [docs/ROADMAP.md](./docs/ROADMAP.md) | Milestones and the distinction between completed and planned work. |
| [docs/contributing.md](./docs/contributing.md) | Local workflow and expectations for changes. |
| [docs/scorecard.md](./docs/scorecard.md) | Performance budgets, measurement status, and regression-corpus floors. |
| [Sources/MotiveEngine/VM/README.md](./Sources/MotiveEngine/VM/README.md) | Robusta language and runtime notes. |

## 2. Workspace map

- `Sources/MotiveEngine/` contains the Swift library. Domain files cover
  motives, items, interactions, autonomy, actions, Sims, households, lots,
  buffs, and broadcasting.
- `Sources/MotiveEngine/VM/` contains the Robusta lexer, frontend, AST, IR,
  compiler pipeline, and runtime.
- `Tests/MotiveEngineTests/` contains the package's Swift Testing suites.
- `schema/` contains JSON schemas for item and SWAF data.
- `docs/` contains the documentation index, architecture overview, roadmap,
  contributor guide, and engineering scorecard.
- `Stash/` holds reference material; it is not an implementation contract.
- `.github/workflows/` defines build, test, and release automation.

## 3. Golden Rules

Keep the engine render-agnostic and favor explicit, typed values and
deterministic transformations. Keep reusable definitions separate from
instance state, and keep eligibility, scoring, and action execution as
separate responsibilities. Preserve public behavior unless a change
intentionally updates it with tests and documentation.

### Never crash

Treat content and caller-provided values as untrusted. Validate them at the
boundary and report invalid input with the existing throwing or result-based
APIs. Do not add force unwraps, traps, or silent fallbacks to handle invalid
content. Keep recoverable failures explicit so a game or tool using the
library can decide how to respond.

## 4. Picking work

Check [docs/ROADMAP.md](./docs/ROADMAP.md) before starting. Prefer the next
unblocked milestone item, and treat unchecked items as plans rather than
available behavior. Use [docs/scorecard.md](./docs/scorecard.md) when a
change affects performance or regression coverage. Measure before optimizing;
record actual results separately from target budgets.

For each change, define the behavior and its boundary cases, add focused tests,
run `swift test`, and update user-facing docs when behavior or supported APIs
change. Keep changes small enough to review and avoid coupling optional
extensions to core simulation behavior.

## 5. Where things are tracked

- Milestone status and sequencing: [docs/ROADMAP.md](./docs/ROADMAP.md).
- Performance targets and corpus floors: [docs/scorecard.md](./docs/scorecard.md).
- Executable behavior: `Sources/` and regression tests in `Tests/`.
- Public concepts and intended boundaries: [docs/architecture.md](./docs/architecture.md).
- Contribution workflow: [docs/contributing.md](./docs/contributing.md).

Use issues or pull requests for discussion and coordination. Keep durable
project status in the roadmap and scorecard rather than relying on chat history.
