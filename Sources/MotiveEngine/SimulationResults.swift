/// A deterministic, read-only view of a validated simulation state.
public struct SimulationSnapshot: Equatable, Sendable {
    /// Sims ordered by stable identifier.
    public let sims: [SimStateData]

    /// Households ordered by stable identifier.
    public let households: [HouseholdState]

    /// Lots ordered by stable identifier.
    public let lots: [LotState]

    /// Creates a snapshot with top-level entities ordered by stable identifier.
    ///
    /// Construction is O(n log n) in the number of Sims, households, and lots.
    public init(state: SimulationState) {
        sims = state.sims.values.sorted { $0.id.rawValue < $1.id.rawValue }
        households = state.households.values.sorted { $0.id.rawValue < $1.id.rawValue }
        lots = state.lots.values.sorted { $0.id.rawValue < $1.id.rawValue }
    }
}

/// A typed fact about a change produced during a simulation step.
public enum SimulationEvent: Equatable, Sendable {
    /// A Sim's motive values changed.
    case motivesChanged(simID: SimID, motives: MotiveLevels)

    /// Buff rules and timed buffs contributed effects to a Sim.
    case buffsApplied(simID: SimID, effects: [BuffEffect])

    /// A timed buff started or restarted on a Sim.
    case timedBuffApplied(simID: SimID, buff: TimedBuff)

    /// A timed buff ran out.
    case timedBuffExpired(simID: SimID, buffID: BuffID)

    /// A Sim's interaction action state changed.
    case actionChanged(simID: SimID, action: InteractionActionState)

    /// A Sim's current lot changed.
    case currentLotChanged(simID: SimID, from: LotID?, to: LotID?)

    /// A Sim changed grid position on its current lot.
    case positionChanged(simID: SimID, from: GridPosition, to: GridPosition)
}

/// The resulting snapshot and ordered events from one simulation step.
public struct SimulationStepResult: Equatable, Sendable {
    /// The simulation state after the step.
    public let snapshot: SimulationSnapshot

    /// Facts produced during the step, in emission order.
    public let events: [SimulationEvent]

    /// Creates a result for one completed simulation step.
    public init(snapshot: SimulationSnapshot, events: [SimulationEvent] = []) {
        self.snapshot = snapshot
        self.events = events
    }
}
