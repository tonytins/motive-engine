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

The Sim scheduler, motive decay and fulfillment loop, concrete
interaction model, Lot simulation actor, and aspiration lifecycle are
not yet implemented as complete systems. The APIs and examples in this
overview describe direction, not guarantees about available runtime
features. Motive decay and fulfillment arithmetic exists as pure value
operations, but it is not yet connected to a running simulation tick.

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
lot placement or instance uniqueness; those belong to future world
state.

```swift
if let chairDefinitionID = ItemDefinitionID("basic-chair"),
   let chairInstanceID = ItemInstanceID("living-room-chair")
{
    let chairDefinition = ItemDefinition(
        id: chairDefinitionID,
        identity: ItemIdentity(name: "Basic Chair", itemTypes: .chair),
        signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 1)]
    )
    let catalog = try ItemDefinitionCatalog(definitions: [chairDefinition])
    let placedChair = PlacedItem(
        id: chairInstanceID,
        definitionID: chairDefinitionID,
        position: GridPosition(x: 2, y: 3)
    )
}
```

## Needs, interactions, and autonomy

Motives represent immediate needs whose values change over simulated
time. Items should make concrete interactions available, and those
interactions should advertise their expected motive benefits separately
from the effects they actually apply.

An autonomy policy should inspect a snapshot of relevant Sim state and
viable interaction offers, then return a decision or ranked candidates.
It should not perform movement or mutate authoritative simulation state
as a side effect of scoring. Player commands and autonomous choices
should ultimately use the same action execution model, while selection
policy determines which action is chosen.

The exact motive scale, decay rules, urgency thresholds, scoring, and
command precedence still require design and tested examples.

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

1. Complete and test the current value-level motive and item primitives.
2. Define interaction offers and item definitions without changing
   storage or JSON formats prematurely.
3. Implement pure motive-urgency and opportunity-scoring systems.
4. Represent Sim activity, commands, and transitions as explicit state
   and testable transformations.
5. Define event and extension contracts for buffs and aspirations.
6. Coordinate systems through explicit simulation phases and snapshots.
7. Integrate movement, lot/household state, and the scripting boundary.

Each step should preserve working behavior, add focused tests, and
document user-facing APIs once they are supported.
