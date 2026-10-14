# Motive Engine Roadmap

This roadmap tracks the gradual shift toward a data-oriented simulation
library. Milestone names come from Shinkansen routes; the route names are
labels, not claims about relative speed or release dates.

Completed items reflect behavior already present in the codebase. An
unchecked item is planned work, not an implemented feature.

## Tokaido: Establish tested foundations

- [x] Keep the core render-agnostic and document the proposed architecture.
- [x] Add a public `/docs` entry point and architecture overview.
- [x] Expose complete, validated motive snapshots and decay-rate tables.
- [x] Apply motive decay and fulfillment as pure transformations.
- [x] Add focused tests for bounds, invalid input, clamping, and deterministic
  lowest-motive selection.
- [x] Correct rectangular grid bounds, hybrid ambient detection, and
  household sleep/reachability tracking.
- [x] Add a release workflow for `rel/*` and `release/*` branches that runs
  `swift test` before publishing an archive.

## Sanyo: Separate content from instances

- [x] Introduce stable, content-supplied item-definition and item-instance
  identifiers.
- [x] Store reusable item content separately from placed-item identity and
  position.
- [x] Add an indexed item-definition catalog with duplicate-ID validation.
- [x] Verify multiple placed instances can reference the same definition.
- [ ] Define catalog composition, overrides, and content-loading policy
  without coupling reusable definitions to a lot.

## Tohoku: Describe interaction offers

- [x] Add reusable interaction definitions with stable IDs.
- [x] Keep advertised motive benefits separate from applied motive effects.
- [x] Produce instance-specific offers from a definition and placed item.
- [x] Reject empty interaction names, non-finite strengths, and duplicate
  interaction IDs within one item definition.
- [x] Document that offers are candidates, not proof of eligibility or
  reachability.
- [x] Add an optional required-posture interaction requirement.
- [ ] Add broader contextual offer generation as more requirements are
  established.

## Hokuriku: Determine eligibility

- [x] Define typed requirements for posture and snapshots for actor/item
  availability.
- [x] Represent capacity and occupancy as explicit item snapshot data.
- [x] Evaluate eligibility from optional immutable snapshots and return
  explicit reasons when an offer is unavailable.
- [x] Test eligible, ineligible, missing-context, and capacity-boundary cases
  without a running simulation actor.
- [ ] Add broader typed requirements for actor state, item state, and
  interaction availability.

## Joetsu: Rank autonomous opportunities

- [x] Define continuous motive urgency and the positive-score usefulness
  cutoff with test examples.
- [x] Score eligible offers from motive state and advertised benefits.
- [x] Specify deterministic tie-breaking and behavior when no offer is useful.
- [x] Return explainable ranked candidates or a choice without mutating
  simulation state.
- [x] Keep player-command priority and free-will policy separate from action
  execution.

## Kyushu: Model action execution

- [x] Define action state, start/progress/completion, interruption, and
  failure as value data.
- [x] Apply interaction effects through systems, separately from offer
  scoring.
- [x] Represent player commands as explicit inputs to the same action model
  used by autonomy.
- [x] Test transitions and effects with pure inputs and outputs.

## Hokkaido: Coordinate simulation phases

- [x] Define typed Sim, lot, and household state keyed by stable IDs, with
  validated membership, lot references, and item instance identities.
- [x] Specify command, motive, offer, decision, movement, execution, and event
  phase order, including intended data ownership and write order.
- [ ] Add read-only snapshots and structured results/events for clients.
- [ ] Integrate routing and occupancy while keeping movement separate from
  decision scoring.
- [ ] Add a session coordinator; use actors only at concurrency boundaries.

## Nishi-Kyushu: Connect optional extensions

- [ ] Define buff inputs, outputs, evaluation timing, ordering, and
  idempotency.
- [ ] Implement aspirations as an optional, independently testable extension
  that can express wants and fears.
- [ ] Define the typed data boundary between the Robusta VM and item
  interactions.
- [ ] Verify simulations remain usable when optional extensions are absent.

## Akita: Measure before optimizing

- [x] Benchmark representative workloads before changing collection layout.
- [ ] Consider batched or structure-of-arrays storage only if measurements
  justify it.
- [ ] Preserve observable behavior and public domain types when changing
  storage.

## Next milestone

Continue with **Hokkaido**: coordinate typed Sim, lot, and household state
through explicit simulation phases. Broader contextual requirements and
catalog loading remain deferred until concrete needs arise.
