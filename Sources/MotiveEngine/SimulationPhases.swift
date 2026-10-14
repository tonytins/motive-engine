/// An ordered stage in a simulation step.
///
/// The phase order defines intended data ownership and write order. It does
/// not imply that every phase has an implementation yet.
public enum SimulationPhase: String, CaseIterable, Sendable {
    /// Apply queued player and system commands.
    case commands

    /// Apply passive motive decay.
    case motiveDecay

    /// Generate interaction offers from current world state.
    case offerGeneration

    /// Check offers against current actor and item context.
    case eligibility

    /// Rank eligible offers for autonomous actors.
    case autonomousDecision

    /// Update actor positions independently from choosing actions.
    case movement

    /// Advance active actions and apply their effects.
    case actionExecution

    /// Report facts produced by the completed step.
    case events
}

/// The standard phase order for one simulation step.
public enum SimulationPhasePlan {
    /// Commands, state updates, derived decisions, execution, then events.
    ///
    /// Command and action phases write authoritative state. Offer generation,
    /// eligibility, and autonomous decision phases produce derived values.
    /// Movement updates positions after decisions. Event emission observes the
    /// resulting state and does not change it.
    public static let standardOrder = SimulationPhase.allCases
}
