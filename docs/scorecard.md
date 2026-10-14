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

- 2026-10-14: `swift test` passed 86 tests across 12 suites after adding
  the simulation phase plan. The optimized benchmark measurements above were
  collected on the same date.

## Regression corpus floors

These are minimum coverage expectations for the maintained test corpus, not
claims about the current number of tests. Keep fixtures small and deterministic.

| Area | Minimum corpus floor |
| --- | --- |
| Motives | Exercise all 6 `MotiveType` values; cover levels 0, 50, and 100; cover zero and positive decay; reject missing values, out-of-range/non-finite values, negative elapsed time, and non-finite signals. |
| Item definitions and offers | Use 1 definition referenced by at least 2 placed instances; cover a valid offer, duplicate IDs, an unknown definition, invalid duration, and non-finite benefit/effect strengths. |
| Eligibility | Cover every declared eligibility failure reason, missing snapshots, a passing case, occupancy exactly at capacity, and occupancy above capacity. |
| Autonomy | Cover all 6 motives, positive/zero/negative scores, no useful offer, non-finite scoring input, and ties resolved by each documented identifier key. |
| Actions | Cover start, progress, completion, duration overrun, interruption, failure, and attempts to advance or terminate a terminal action. |
| Grid and household utilities | Cover rectangular bounds and edges, reachable and unreachable paths, ambient classifications, and sleep/wake roster changes including repeated events. |
| World state and phase plan | Cover stable ID validation, duplicate and missing references, household membership, lot bounds and placement uniqueness, and the declared phase order. |
| Robusta | Keep at least one valid fixture for each supported token and language construct; cover malformed input, diagnostic/error paths, and equivalent source/AST/IR execution where supported. |
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

### Robusta

- [ ] Lexer and parser fixtures cover successful and invalid input.
- [ ] IR encode/decode behavior rejects unknown or malformed instructions.
- [ ] Runtime errors remain explicit and do not terminate the host process.
- [x] Performance is measured using the same 10,001-token source corpus.

### Documentation and schemas

- [ ] Schemas match the supported decoding and validation behavior.
- [ ] Proposed behavior is labeled as planned rather than implemented.
- [ ] Public API or behavior changes are reflected in the relevant docs.
