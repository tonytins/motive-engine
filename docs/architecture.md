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
- an optional buff contract with an ambient buff rule;
- an optional wants and fears (SWAF) extension with tag- and motive-weighted
  rolls, an aspiration bar, and reward points;
- grid geometry and pathfinding;
- a partial household sleep-event roster;
- the independent Robusta scripting implementation.

The Sim scheduler, running simulation tick, and Lot coordinator are not yet
implemented as complete systems. Motive transformations,
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

Every stable identifier, such as `SimID`, `ItemDefinitionID`, or `BuffID`,
conforms to `StringIdentifier`: it rejects empty strings when created or
decoded and encodes as a single JSON string. `ItemDefinitionID` and
`ItemInstanceID` are distinct, content-supplied string identifiers. A definition catalog stores reusable content by
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
references, per-lot Sim positions, and global item-instance uniqueness when
it is created. A Sim on a lot must have an in-bounds grid position, and two
Sims cannot occupy the same tile.
Households and lots are independent: household members can be on different
lots, and a Sim can have no current lot or position. A Sim state holds motive
values, posture, and an optional active interaction action. `GridSize` exposes
lot bounds through `LotState`, which requires positive dimensions.

`ItemDefinition.interactionCapacity` defaults to one and must be positive.
The session counts an active interaction as a capacity reservation, including
while its Sim is routing to the item.

`InteractionRoutingSystem` finds a deterministic shortest path to a free
orthogonal neighbor of an interaction item. Blocking item tiles and tiles
occupied by other Sims are excluded from both paths and approach positions.
Movement remains separate from autonomy scoring.

`SimulationSnapshot` exposes the state as read-only entity arrays ordered by
stable ID for deterministic client iteration. `SimulationStepResult` pairs a
resulting snapshot with ordered `SimulationEvent` values for motive changes,
buff effects, timed buffs starting and expiring, action changes, current-lot
changes, and position changes.

`SimulationPhasePlan.standardOrder` records the intended order:
commands, motive decay, buffs, offer generation, eligibility, autonomous
decision, movement, action execution, then events. Commands and action
execution own authoritative writes; motive decay and buffs update motive
state;
offer generation, eligibility, and decision produce derived values;
movement updates position after action selection; events observe the final
step state.

`SimulationSession` coordinates one validated world state across simulation
steps. It applies player interaction and cancellation commands,
decays motives, applies optional buffs, chooses reachable eligible interactions for idle Sims,
moves actors one grid tile per step, and advances an action only after the
Sim reaches an available adjacent tile. Sims and events are processed in
stable-ID and phase order. A cancellation suppresses autonomous reselection
for that Sim during the same step. Scripted interactions run when their action starts.
If an offer has a script, the session evaluates it with the Sim's current
state, and the action applies the script's effects instead of the written
`motiveEffects` for its whole duration. The effects are stored in the
action's `motiveEffects`. A script that throws, exceeds the instruction
limit, or reports an invalid effect does not stop the step: the action ends
as `.failed(.scriptFailed(failure))`, where the typed
`InteractionScriptFailure` separates runtime errors from invalid effects, and
an `actionChanged` event reports it. Invalid `effect.fulfill` calls with
literal arguments are rejected earlier, when the script is created.
A failed player command then keeps autonomy idle for that Sim for the rest of
the step, while autonomy reports the failure and tries the next useful offer.
Advertised benefits are unaffected, so scripts do not change ranking. An action waits if other Sims temporarily
occupy every approach tile and fails only when the static lot layout has no
route. A rejected command leaves the session unchanged. The session does not
transfer Sims between lots or own concurrency; callers can isolate it at their
concurrency boundary.

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
the needs system depend on a particular extension. The contract is:

- **Inputs.** A `BuffRule` receives a read-only `BuffContext`: one Sim's
  state, its current lot (if any), and the item catalog.
- **Outputs.** A rule returns per-second `MotiveSignal` values, or none when
  it does not apply. `BuffSystem.evaluate` rejects non-finite signals,
  attributes the rest as `BuffEffect` values, and applies them over the
  elapsed time.
- **Timing.** `SimulationSession` evaluates buffs in the `buffs` phase,
  after motive decay and before offer generation, so autonomy reads
  buffed motives. Buffs see positions from before that step's movement.
  For each Sim with effects, the step emits `buffsApplied` followed by
  `motivesChanged` when the values differ.
- **Ordering.** `BuffRuleSet` rejects duplicate `BuffID` values and runs
  rules in ID order. Sims are processed in stable-ID order. All signals are
  summed before clamping, so motive results do not depend on rule order.
- **Idempotency.** Rules must be pure and hold no state. Evaluating the same
  context returns the same result, each rule applies once per step, and
  zero elapsed time reports effects without changing motives.

Timed buffs cover effects that last a limited time, such as a "Fulfilled"
mood after a wish. A `TimedBuff` has a `BuffID`, per-second signals, and the
seconds remaining; it is instance state stored in `SimStateData.timedBuffs`,
at most one per ID. The `applyBuff` command starts one and emits
`timedBuffApplied`; applying an ID that is already active restarts it rather
than stacking. In the `buffs` phase each timed buff applies only for its
remaining time, after rule effects, and is removed with a
`timedBuffExpired` event when it runs out. Timed buffs work without any
buff rules.

Buffs are optional: a session created without a rule set applies none and
emits no buff events. `AmbientBuffRule` applies the signals of every
`.ambient` item on the Sim's lot within a Manhattan radius, visiting items
in instance-ID order; hybrid items, such as an ambient stereo that also
offers interactions, qualify.

### Wants and fears

Wants and fears (SWAF) give the player goals and let a Sim communicate what
it cares about. They ship as a separate library product, `MotiveEngineSWAF`
(`Sources/MotiveEngineSWAF/`), built only on the core's public API. A game
that does not want them depends on `MotiveEngine` alone. SWAF observes the
simulation: it reads motives and step events but never changes motives,
actions, or free will.

- **Content.** A `WantFearCatalog` holds `WantFearDefinition` values, decoded
  from JSON matching `schema/swaf.json`. Each has a stable ID, a want or
  fear kind, a player-facing name, a trigger, roll weights, aspiration
  points, and reward points.
- **Tags.** Aspirations, life stages, traits, hobbies, seasons, and recent
  events are game-defined `SWAFTag` values on the Sim's
  `AspirationProfile`. Entries can require tags and add weight for others;
  the engine only compares them.
- **Rolling.** An entry's weight is its base weight, plus its tag weights,
  plus each motive weight times that motive's urgency
  (`(100 - level) / 100`), so a tired Sim tends to roll a want to sleep.
  Draws are weighted, without repeats, visit candidates in ID order, and use
  a seed stored in `AspirationState`, so a seed always gives the same board.
- **Board.** The profile sets want and fear slot counts (four and three by
  default) and a lock limit (one by default). `AspirationSystem.reroll`
  replaces every unlocked slot; the game decides when, such as on waking or
  visiting a community lot. Locked entries survive rerolls until fulfilled.
  A saved board can be restored through the `AspirationState` initializer.
- **Triggers.** `observe` fulfills entries from completed interactions in a
  step's events and from motives below a level. `report` handles named game
  events, such as a promotion, and `fulfill` completes one entry directly.
  Each fulfilled slot is rerolled once, never to the same entry.
- **Scores.** A fulfilled want raises the 0–100 aspiration bar and earns
  reward points; a realized fear lowers both, without reward points going
  below zero. `decay` lowers the bar over time. A profile can stop tracking
  the bar, as for townies, while reward points still change. What happens at
  a low bar, and what reward points buy, is game policy.

- **Wish mode.** Profile options give Sims 3-style wishes: no fear slots,
  no aspiration tracking, `requiresPromise` so only locked (promised)
  entries can be fulfilled, and `offerLifetimeSeconds` so `advance` removes
  unpromised entries that reach that age. An expired slot stays empty until
  the next reroll. `cancel` removes any entry. The lock limit is the number
  of wishes that can be promised at once. A profile's `fulfillmentBuff` is
  a `TimedBuff` granted whenever a want is fulfilled. SWAF does not apply it:
  the update's `commands` carry `applyBuff` commands for the game to pass to
  the next session step.

Operations are pure: each returns a new state and ordered
`AspirationEvent` values, and leaves the state unchanged on error. Wants and
fears that target a specific Sim or item, and lifetime wants, are planned.

Robusta is an independent scripting subsystem for authorable behavior.
It connects to item interactions through a narrow, typed boundary:
`InteractionScript` compiles a program once, and
`InteractionScriptSystem.evaluate` runs it against an
`InteractionScriptInput` built from a Sim and an offer. Scripts read
immutable inputs such as `sim.hunger` and `interaction.duration`, and
report effects only by calling `effect.fulfill(motive, strengthPerSecond)`.
The engine validates those calls into `MotiveSignal` values; scripts never
read or write authoritative state. Evaluation is pure and deterministic.
The session runs an interaction's script once when its action starts. See the
[Robusta README](../Sources/MotiveEngine/VM/README.md#host-boundary) for
the full input table and error behavior.

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
6. [x] Define event and extension contracts for buffs and aspirations.
7. Coordinate systems through explicit simulation phases and snapshots.
8. Integrate movement, lot/household state, and the scripting boundary
   (scripts run when actions start).

Each step should preserve working behavior, add focused tests, and
document user-facing APIs once they are supported.
