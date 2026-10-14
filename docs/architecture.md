# Architecture Overview

Motive Engine is intended to provide reusable simulation AI for
Sims-style life simulation games. It draws inspiration from needs-driven
autonomy while defining its own rules. The library should remain
independent of a game's renderer, UI, and presentation.

## Current foundations

The current codebase contains early building blocks, not a complete
simulation loop:

- motive values and signals, including complete per-Sim motive snapshots
  with clamped 0–100 values and pure `MotiveSystem.decay` and
  `MotiveSystem.fulfill` transformations;
- complete, finite, nonnegative per-second decay-rate tables;
- item identities, modifiers, and JSON motive-signal decoding;
- a basic ambient buff extension;
- personality traits and wants/fears catalog utilities;
- grid geometry and pathfinding;
- a partial household sleep-event roster;
- the independent Robusta scripting implementation.

The Sim scheduler, running simulation tick, Lot coordinator, and aspiration
lifecycle are not yet implemented as complete systems. Motive transformations,
interaction offers and eligibility, autonomy scoring, and action transitions
exist as independently testable value-level systems, but are not yet connected
by a complete simulation loop. The APIs and examples in this overview describe
direction where features remain planned; consult the roadmap for current status.

Motive state requires a value for every `MotiveType`; missing values or
decay rates are rejected during construction. Finite motive levels are
clamped to 0–100. Decay rates must be finite and nonnegative. Elapsed
time must be finite and nonnegative. Fulfillment signals may be negative
to support draining effects, but must be finite. Equal lowest motive
values are resolved in `MotiveType` declaration order for repeatable
results.

The transformations are exposed as a system over immutable value
snapshots:

```swift
let levels = try MotiveLevels(
    levels: Dictionary(uniqueKeysWithValues: MotiveType.allCases.map { ($0, 50.0) })
)
let decayRates = try MotiveDecayRates(
    ratesPerSecond: Dictionary(uniqueKeysWithValues: MotiveType.allCases.map { ($0, 0.01) })
)
let nextLevels = try MotiveSystem.decay(levels, using: decayRates, overSeconds: 1)
```

## Data-oriented direction

The simulation should center on explicit data and systems that transform
it, rather than placing the simulation rules inside objects representing
individual Sims or items. This does not require a full ECS. Begin with
ordinary typed Swift values and collections; specialize storage only if
measured scale requires it.

Keep these concepts distinct:

- **Definitions** are reusable content, such as item definitions,
  interaction offers, motive profiles, buff rules, and aspiration
  catalogs.
- **Instance state** is the changing state of a particular Sim, item,
  household, or lot.
- **Commands and events** represent requested actions and facts observed
  during simulation.
- **Systems** read explicit inputs and produce state changes or results.
- **Snapshots and reports** expose read-only views to decision policies,
  extensions, debugging tools, and the game.

`ItemDefinitionID` and `ItemInstanceID` are distinct, content-supplied
string identifiers. A definition catalog stores reusable content by
definition ID, while `PlacedItem` stores an instance ID, a definition
reference, and a position. Multiple placed instances can therefore
share one item definition without duplicating its content. Empty IDs and
duplicate definition IDs are rejected. The catalog does not yet manage
lot placement or instance uniqueness. `LotState` validates placement
bounds and local uniqueness, while `SimulationState` validates that item
instance IDs are unique across lots.

`SimStateData`, `HouseholdState`, and `LotState` hold world state keyed by
the stable `SimID`, `HouseholdID`, and `LotID` values. `SimulationState`
indexes these values and validates household membership, current-lot
references, and global item-instance uniqueness when it is created.
Households and lots are independent: household members can be on different
lots, and a Sim can have no current lot. A Sim state holds motive values,
posture, and an optional active interaction action. `GridSize` exposes
lot bounds through `LotState`, which requires positive dimensions.

This is a validated state container, not yet a simulation coordinator.
It does not process commands or events, move Sims, or track occupant
positions.

`SimulationSnapshot` exposes the state as read-only entity arrays ordered by
stable ID for deterministic client iteration. `SimulationStepResult` pairs a
resulting snapshot with ordered `SimulationEvent` values for motive changes,
action changes, and current-lot changes. These are public data contracts;
the simulation coordinator that produces them remains future Hokkaido work.

`SimulationPhasePlan.standardOrder` records the intended order:
commands, motive decay, offer generation, eligibility, autonomous
decision, movement, action execution, then events. Commands and action
execution own authoritative writes; motive decay updates motive state;
offer generation, eligibility, and decision produce derived values;
movement updates position after action selection; events observe the final
step state. This phase list is a tested contract, not a simulation runner.

An `ItemDefinition` can also contain reusable `InteractionDefinition`
values. Each interaction has its own stable ID, a name, advertised
`MotiveBenefit` values, separate `MotiveSignal` effects, and
`InteractionRequirements`. Requirements currently support a required
actor posture.
`ItemDefinitionCatalog.interactionOffers(for:)` combines those
definitions with a `PlacedItem` to produce instance-specific
`InteractionOffer` values. Offers contain advertised benefits and the
separate execution effects and duration from their definition. They are
candidates for eligibility checks, not proof that an interaction is
reachable or currently usable. The catalog resolves an unknown item
definition as an error, and rejects duplicate interaction IDs within
one item definition. Durations must be positive and finite. Advertised
benefits and actual effects must have finite strengths, but they are
deliberately allowed to differ.

`InteractionEligibilitySystem.evaluate` checks an offer against optional
actor and item snapshots. Actor snapshots provide posture and whether
the actor can start another interaction. Item snapshots provide current
availability, capacity, and occupancy. Missing snapshots, unavailable
actors/items, posture mismatches, and full capacity are returned as
explicit reasons in a stable order. Snapshot construction rejects
negative capacity or occupancy; zero capacity and over-capacity
occupancy are represented and report as full. Eligibility does not
check location, routing, motives, or autonomy policy.

`AutonomyScoringSystem.rank` accepts offers the caller has already found
eligible and scores them against a complete `MotiveLevels` snapshot.
For each motive, urgency is `(100 - level) / 100`. Advertised benefit rates
are summed per motive and multiplied by that motive's urgency; negative
benefits lower the score. The explainable result includes each motive's
level, urgency, combined advertised rate, and weighted contribution.

Ranked candidates sort by descending score, then item-instance ID,
item-definition ID, and interaction ID. An offer is useful only when its
total score is greater than zero, so the ranking has no selected offer
when all scores are zero or negative. Non-finite scores are reported as
errors. Scoring neither
changes motive state nor applies the separate execution effects. Eligibility
must be evaluated by the caller first; player-command priority and free-will
policy are not part of this scoring system.

`InteractionActionSystem.start` creates an action state from an offer
selected by either `.playerCommand` or `.autonomy`. The caller checks
eligibility before starting. `advance` applies motive effects only over
the active time in that step, bounded by the configured duration. When
the duration is reached, the action completes; excess requested time is
ignored. Interruption and failure stop a running action without undoing
effects already applied. Failure reasons are explicit values supplied by
the caller. Terminal actions cannot be advanced or terminated again.
These transitions return new values and do not own or mutate authoritative
simulation state.

```swift
if let chairDefinitionID = ItemDefinitionID("basic-chair"),
   let chairInstanceID = ItemInstanceID("living-room-chair"),
   let sitInteractionID = InteractionDefinitionID("sit")
{
    let chairDefinition = ItemDefinition(
        id: chairDefinitionID,
        identity: ItemIdentity(name: "Basic Chair", itemTypes: .chair),
        signals: [],
        interactions: [
            try InteractionDefinition(
                id: sitInteractionID,
                name: "Sit",
                advertisedBenefits: [
                    MotiveBenefit(motiveType: .fun, expectedStrengthPerSecond: 0.5)
                ],
                motiveEffects: [
                    MotiveSignal(motiveType: .fun, strengthPerSecond: 0.25)
                ],
                durationSeconds: 60
            )
        ]
    )
    let catalog = try ItemDefinitionCatalog(definitions: [chairDefinition])
    let placedChair = PlacedItem(
        id: chairInstanceID,
        definitionID: chairDefinitionID,
        position: GridPosition(x: 2, y: 3)
    )
    let offers = try catalog.interactionOffers(for: placedChair)
}
```

## Needs, interactions, and autonomy

Motives represent immediate needs whose values change over simulated
time. Item definitions now provide interaction offers and distinguish
their advertised motive benefits from their actual motive effects.
Eligibility checks and pure autonomy ranking are implemented as separate
systems. Actions progress as explicit values, and per-second motive
effects are applied by pure action transitions.

An autonomy policy should inspect a snapshot of relevant Sim state and
viable interaction offers, then return a decision or ranked candidates.
It should not perform movement or mutate authoritative simulation state
as a side effect of scoring. Player commands and autonomous choices
should ultimately use the same action execution model, while selection
policy determines which action is chosen.

The motive value scale is 0–100, with lower values representing greater
need. The first-pass continuous urgency formula and positive-score
usefulness cutoff are documented above. Decay rules and command precedence
remain game-specific policy.

## Pluggable extensions

Buffs provide a place for passive or contextual effects without making
the needs system depend on a particular extension. The boundary is also
intended to support optional aspiration systems, including a
Wants/Fears-inspired system. Aspirations are longer-horizon goals, not
simply another physical motive, and their relationship to buffs remains
to be designed.

Robusta is an independent scripting subsystem for authorable behavior.
Future integration should use a narrow, typed boundary: scripts receive
declared data and return declared offers or effects. Core simulation
rules and authoritative state remain owned by engine systems.

## A gradual implementation path

1. [x] Complete and test the current value-level motive and item primitives.
2. [x] Add eligibility requirements and contextual offer generation without
   coupling definitions to lot state.
3. [x] Implement pure motive-urgency and opportunity-scoring systems over
   the advertised benefit data.
4. [x] Define interaction execution and apply effects separately from offer
   scoring.
5. [x] Represent action source, activity, and transitions as explicit state
   and testable transformations.
6. Define event and extension contracts for buffs and aspirations.
7. Coordinate systems through explicit simulation phases and snapshots.
8. Integrate movement, lot/household state, and the scripting boundary.

Each step should preserve working behavior, add focused tests, and
document user-facing APIs once they are supported.
