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
  validated membership, lot references, Sim positions, and item instance
  identities.
- [x] Specify command, motive, offer, decision, movement, execution, and event
  phase order, including intended data ownership and write order.
- [x] Add deterministic read-only snapshots and structured step results/events
  for clients.
- [x] Route Sims to free adjacent interaction tiles while respecting blocking
  items and Sim occupancy.
- [x] Add item interaction capacity and reserve capacity for active actions.
- [x] Coordinate commands, motive decay, autonomy, movement, action execution,
  snapshots, and events with a deterministic value-type session.
- [x] Keep concurrency outside the session coordinator.

## Nishi-Kyushu: Connect optional extensions

- [x] Define buff inputs, outputs, evaluation timing, ordering, and
  idempotency.
- [x] Implement aspirations as an optional, independently testable extension
  that can express wants and fears.
- [x] Ship SWAF as a separate `MotiveEngineSWAF` library product that uses
  only the core's public API.
- [x] Support Sims 3-style wishes through profile options: promises, offer
  expiry that leaves slots empty, and cancellation.
- [ ] Add wants and fears that target a specific Sim or item, and lifetime
  wants, including bonus points for wishes related to a lifetime wish.
- [ ] Add timed buffs so fulfilling a wish can grant a temporary
  "Fulfilled" mood effect.
- [x] Define the typed data boundary between the Robusta VM and item
  interactions.
- [x] Verify simulations remain usable when optional extensions are absent.
  Covers buffs and interaction scripts. Aspirations only observe simulation
  events, so the session never depends on them.

## Akita: Measure before optimizing

- [x] Benchmark representative workloads before changing collection layout.
- [ ] Consider batched or structure-of-arrays storage only if measurements
  justify it.
- [ ] Preserve observable behavior and public domain types when changing
  storage.

## Next milestone

Continue with **Nishi-Kyushu**: connect optional extensions without making
them dependencies of the core simulation. Earlier unchecked catalog and
contextual-requirement items remain planned until concrete content needs
define their behavior.
