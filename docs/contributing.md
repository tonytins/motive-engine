# Contributing

Motive Engine is a Swift package for simulation systems that should remain
independent of rendering and presentation. Contributions should fit the
implemented APIs, keep boundaries explicit, and distinguish working behavior
from roadmap proposals.

## Before changing code

1. Read the [project overview](../README.md), [architecture](./architecture.md),
   and [roadmap](./ROADMAP.md).
2. Check [AGENTS.md](../AGENTS.md) for repository-wide guidance.
3. Confirm a roadmap item or issue describes the intended behavior. If the
   work introduces a new behavior, state its inputs, outputs, and failure
   cases in the change.

## Build and test

The package declares Swift 6.3 as its minimum tools version. From the
repository root, run:

```sh
swift build
swift test
```

Tests use Swift Testing under `Tests/MotiveEngineTests/`. Add focused
regression tests alongside the relevant suite. Prefer deterministic tests of
typed inputs and outputs; avoid timing-based assertions in unit tests.

## Implementation expectations

- Validate external and content data at API boundaries. Report invalid input
  through explicit errors or result values rather than traps or silent defaults.
- Keep systems independently testable and their inputs and outputs explicit.
- Preserve deterministic ordering when results can be tied.
- Keep definitions, instance state, eligibility, scoring, and action execution
  as separate concepts.
- Avoid adding dependencies unless the change needs them.
- Do not present roadmap features as supported APIs before they are implemented.

## Documentation

Update documentation when a change affects a public API, supported behavior,
or the recommended workflow. Use `docs/README.md` as the public documentation
index, `docs/architecture.md` for system boundaries, and `docs/ROADMAP.md` for
milestone status. Record performance measurements and changes to coverage
floors in the [scorecard](./scorecard.md); mark estimates as estimates.

## Pull requests

Describe the problem and behavior change, link related issues when available,
and summarize validation performed. Call out public API changes, deferred
work, and any performance tradeoffs. Keep unrelated cleanup out of the
change so review can focus on its behavior.
