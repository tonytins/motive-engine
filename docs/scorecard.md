# Engineering Scorecard

> Generated scorecard for performance budgets, corpus floors, and per-area
> regression checklists. Update this document when the workloads or supported
> behavior change.

## Performance budgets

The p95 budgets below are enforced by the `ci.yml` workflow. The measurements
are an initial local baseline and are not from a pinned runner. Re-run them on
a consistent host before using them to compare changes.

Use an optimized Swift build, warm each workload before sampling, and report
the p95 of at least 30 timed iterations. Exclude fixture construction and
include the full operation under test. Record the Swift version, machine, and
build configuration with results.

| Area | Workload | Budget (p95) | Measured p50 | Measured p95 |
| --- | --- | ---: | ---: | ---: |
| Motives | Decay 10,000 complete motive snapshots across all 6 motive types for one simulated second | 50 ms | 24.353 ms | 35.050 ms |
| Eligibility | Evaluate 10,000 offers against prebuilt actor and item snapshots | 50 ms | 0.675 ms | 0.881 ms |
| Autonomy | Rank 1,000 eligible offers against a complete 6-motive snapshot | 25 ms | 1.291 ms | 1.516 ms |
| Robusta | Tokenize and compile a 10,001-token representative source corpus | 100 ms | 16.697 ms | 19.534 ms |

Measurements were collected on 2026-10-14 with Swift 6.3.3 in release
configuration on Linux x86_64 (Bazzite, kernel 7.2.9). Each workload used one
warm-up followed by 30 timed samples. The benchmark executable is
`swift run -c release MotiveEngineBenchmarks`; fixture construction is outside
the timed region. CI runs the same command and writes its results to the
workflow summary. The Robusta corpus has 10,001 tokens including EOF.

Do not trade determinism, validation, or observable behavior for a budget.
When a workload exceeds its limit, profile it first and keep the benchmark
input and environment fixed while comparing changes.

## Latest test result

- 2026-10-14: `swift test` passed 160 tests after adding content packs.

- 2026-10-14: `swift test` passed 144 tests after adding typed script
  failures and load-time `effect.fulfill` checks.

- 2026-10-14: `swift test` passed 141 tests after running interaction scripts
  in the simulation session.

- 2026-10-14: `swift test` passed 136 tests after aligning the code with the
  Swift style guide: shared `StringIdentifier` conformance, removed dead
  code, documented public API, and parameterized tests.

- 2026-10-14: `swift test` passed 134 tests after adding timed buffs and the
  SWAF fulfillment buff.

- 2026-10-14: `swift test` passed 128 tests after adding SWAF wish mode.

- 2026-10-14: `swift test` passed 123 tests across 14 suites after moving
  SWAF into the `MotiveEngineSWAF` target with its own test target.

- 2026-10-14: `swift test` passed 124 tests across 14 suites after replacing
  the sample wants and fears utilities with the SWAF extension.

- 2026-10-14: `swift test` passed 112 tests across 14 suites after adding
  optional-extension absence tests.

- 2026-10-14: `swift test` passed 109 tests across 13 suites after adding
  the typed Robusta interaction-script boundary.

- 2026-10-14: `swift test` passed 101 tests across 12 suites after adding
  the buff contract, the `buffs` session phase, and the ambient buff rule.

- 2026-10-14: `swift test` passed 95 tests across 12 suites after adding
  Sim positions, interaction routing, and the simulation session. The
  optimized benchmark measurements above were collected on the same date.

## Regression corpus floors

These are minimum coverage expectations for the maintained test corpus, not
claims about the current number of tests. Keep fixtures small and deterministic.

| Area | Minimum corpus floor |
| --- | --- |
| Motives | Exercise all 6 `MotiveType` values; cover levels 0, 50, and 100; cover zero and positive decay; reject missing values, out-of-range/non-finite values, negative elapsed time, and non-finite signals. |
| Item definitions and offers | Use 1 definition referenced by at least 2 placed instances; cover default and invalid interaction capacity, a valid offer, duplicate IDs, an unknown definition, invalid duration, and non-finite benefit/effect strengths. |
| Eligibility | Cover every declared eligibility failure reason, missing snapshots, a passing case, occupancy exactly at capacity, and occupancy above capacity. |
| Autonomy | Cover all 6 motives, positive/zero/negative scores, no useful offer, non-finite scoring input, and ties resolved by each documented identifier key. |
| Actions | Cover start, progress, completion, duration overrun, interruption, failure, and attempts to advance or terminate a terminal action. |
| Buffs | Cover rule-set ID validation and ordering, effect attribution, summing before clamping, repeatable and zero-time evaluation, invalid time and non-finite signals, ambient radius and lot boundaries, hybrid ambient items, a session with and without buffs, and timed buffs: invalid durations and signals, partial and overrun time, zero time, start, restart without stacking, expiry, missing Sims, and duplicate IDs. |
| Grid and household utilities | Cover rectangular bounds and edges, reachable and unreachable paths, routes around blocked and occupied cells, ambient classifications, and sleep/wake roster changes including repeated events. |
| World state and phase plan | Cover stable ID validation, duplicate and missing references, household membership, Sim position and occupancy, lot bounds and placement uniqueness, deterministic snapshots, ordered step events, session phase behavior, and the declared phase order. |
| Robusta | Keep at least one valid fixture for each supported token and language construct; cover malformed input, diagnostic/error paths, and equivalent source/AST/IR execution where supported. |
| Interaction scripts | Read every declared input, report effects in call order, reject the reserved `effect` module and input assignment, reject each invalid literal `effect.fulfill` call at load time (including nested blocks and wrong argument counts), accept computed arguments, report each invalid computed effect when run, propagate runtime failures and the instruction limit without partial effects, and evaluate repeatably. |
| Scripted interactions in a session | Cover script effects replacing written effects, effects fixed for the action's duration, a failed command script that fails only that action without same-step autonomy, typed runtime and invalid-effect failures, autonomy falling back to the next useful offer, unscripted actions, and offers carrying scripts. |
| Optional extensions | Run a session through autonomous selection, movement, and completion with no extensions; show default, empty, and inert buff rule sets produce identical step results; and execute authored effects without a script. |
| Wants and fears | Decode every trigger form and the schema example; reject unknown motives, empty names, invalid triggers, weights, and points, and duplicate IDs; cover tag requirements, tag and motive weighting, repeatable seeded rolls, empty slots, interaction, motive, game-event, and direct fulfillment, realized fears clamping at zero, untracked aspiration, locking limits and shrinking slots, decay, invalid restored boards, and wish mode: promise-only fulfillment, offer expiry leaving empty slots, aging without a lifetime, cancellation, invalid lifetimes and ages, and fulfillment buffs granted once per update and applied through session commands. |
| Content packs | Reject invalid pack IDs and manifest values; load manifests, items, and scripts from memory and from a folder; report each invalid file with its path; reject paths and symbolic links that leave the pack; order packs after their dependencies; reject duplicate packs, missing dependencies, and cycles; qualify IDs; apply declared overrides and reject undeclared, non-dependency, missing, never-defined, and malformed ones; report competing overrides; decode both schema examples; and run composed content in a session. |
| Schemas and content | Validate representative valid and invalid item and SWAF JSON documents against the schemas and decoding behavior. |

## Per-area checklists

### Motives

- [ ] Values and rates remain complete across all 6 motive types.
- [ ] Bounds, finite-number validation, clamping, and deterministic ties are tested.
- [ ] Pure transformations do not mutate their input snapshots.
- [x] Performance is measured with the 10,000-snapshot workload.

### Content, offers, and eligibility

- [ ] Definitions remain separate from placed-item identity and position.
- [ ] Advertised benefits remain separate from effects applied by actions.
- [ ] Every explicit eligibility reason has a regression case.
- [ ] Capacity boundaries and missing-context behavior are covered.
- [x] Performance is measured with the 10,000-offer workload.

### Autonomy and actions

- [ ] Ranking considers eligible offers only and does not mutate simulation state.
- [ ] Positive-score usefulness and deterministic tie-breaking are covered.
- [ ] Action transitions apply effects only for active elapsed time.
- [ ] Completion, interruption, failure, and terminal-state behavior are covered.
- [x] Performance is measured with the 1,000-offer workload.

### Buffs

- [x] Rule sets reject duplicate IDs and evaluate rules in ID order.
- [x] Evaluation is pure, repeatable, and independent of rule order.
- [x] Sessions without buffs are unchanged; sessions with buffs apply them
  after motive decay.

### Grid and household

- [ ] Non-square maps and edge coordinates are covered.
- [ ] Pathfinding handles blocked, reachable, and unreachable destinations.
- [ ] Sleep/wake tracking is consistent under duplicate or out-of-order events.

### World state and phase plan

- [x] Stable identities, duplicate IDs, and missing world references are
  validated by public API tests.
- [x] Household membership is independent from current lot occupancy.
- [x] Lot bounds and placed-item uniqueness are validated locally and across
  lots.
- [x] The standard simulation phase order is covered by a public API test.
- [x] Snapshots sort entities by stable ID; step results preserve event order.
- [x] Routing avoids blocking items and occupied Sim tiles.
- [x] Session commands, motive decay, autonomy, movement, and action execution
  produce validated state and ordered events.
- [x] Item occupancy reservations respect definition capacity; temporary
  Sim-occupied routes wait instead of failing.

### Robusta

- [ ] Lexer and parser fixtures cover successful and invalid input.
- [ ] IR encode/decode behavior rejects unknown or malformed instructions.
- [ ] Runtime errors remain explicit and do not terminate the host process.
- [x] Performance is measured using the same 10,001-token source corpus.

### Interaction scripts

- [x] Scripts read only declared, immutable inputs.
- [x] Effects are validated by the engine and never applied by the script.
- [x] Failures are explicit errors and return no partial effects.

### Documentation and schemas

- [ ] Schemas match the supported decoding and validation behavior.
- [ ] Proposed behavior is labeled as planned rather than implemented.
- [ ] Public API or behavior changes are reflected in the relevant docs.
