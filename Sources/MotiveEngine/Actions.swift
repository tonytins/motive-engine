/// The policy that selected an interaction action.
public enum InteractionActionInitiator: Equatable, Sendable {
    /// The action was selected by an autonomy policy.
    case autonomy

    /// The action was requested by a player.
    case playerCommand
}

/// Why a running interaction was interrupted.
public enum InteractionActionInterruptionReason: Equatable, Sendable {
    /// A caller or player cancelled the action.
    case cancelled

    /// Another action replaced it.
    case replaced

    /// The simulation interrupted the action for another reason.
    case simulationInterrupted
}

/// Why a running interaction failed.
public enum InteractionActionFailureReason: Equatable, Sendable {
    /// The actor became unavailable while the action was running.
    case actorUnavailable

    /// The item became unavailable while the action was running.
    case itemUnavailable

    /// An external execution step failed.
    case executionFailed
}

/// The lifecycle state of an interaction action.
public enum InteractionActionStatus: Equatable, Sendable {
    /// The action can continue to advance.
    case running

    /// The action reached its configured duration.
    case completed

    /// The action stopped before completion by interruption.
    case interrupted(InteractionActionInterruptionReason)

    /// The action stopped before completion because execution failed.
    case failed(InteractionActionFailureReason)
}

/// A value snapshot of one interaction action.
public struct InteractionActionState: Equatable, Sendable {
    /// The offer being executed.
    public let offer: InteractionOffer

    /// The policy that selected the offer.
    public let initiator: InteractionActionInitiator

    /// Active time accumulated by the action.
    public let elapsedSeconds: Double

    /// The current lifecycle state.
    public let status: InteractionActionStatus

    fileprivate init(
        offer: InteractionOffer,
        initiator: InteractionActionInitiator,
        elapsedSeconds: Double,
        status: InteractionActionStatus
    ) {
        self.offer = offer
        self.initiator = initiator
        self.elapsedSeconds = elapsedSeconds
        self.status = status
    }
}

/// The action and motive state returned by one progression step.
public struct InteractionActionUpdate: Equatable, Sendable {
    /// The updated action value.
    public let action: InteractionActionState

    /// Motive values after applying effects for this step.
    public let motives: MotiveLevels
}

/// An invalid interaction action transition.
public enum InteractionActionError: Error, Equatable, Sendable {
    /// A terminal action cannot be progressed, interrupted, or failed again.
    case actionIsNotRunning
}

/// Pure interaction action transitions and effect application.
public enum InteractionActionSystem {
    /// Creates a running action from a player or autonomy selection.
    ///
    /// The caller must check interaction eligibility before starting the
    /// action. Both player and autonomy choices use the same action state.
    public static func start(
        _ offer: InteractionOffer,
        initiatedBy initiator: InteractionActionInitiator
    ) -> InteractionActionState {
        InteractionActionState(
            offer: offer,
            initiator: initiator,
            elapsedSeconds: 0,
            status: .running
        )
    }

    /// Advances a running action and applies effects for its active time.
    ///
    /// Requested time beyond the action's remaining duration is ignored.
    /// Interrupted or failed actions retain effects already applied.
    ///
    /// - Throws: `InteractionActionError.actionIsNotRunning` if the action
    ///   has already reached a terminal state, or
    ///   `MotiveLevelsError.invalidElapsedSeconds` for invalid elapsed time.
    public static func advance(
        _ action: InteractionActionState,
        motives: MotiveLevels,
        bySeconds elapsedSeconds: Double
    ) throws -> InteractionActionUpdate {
        guard action.status == .running else {
            throw InteractionActionError.actionIsNotRunning
        }
        guard elapsedSeconds.isFinite, elapsedSeconds >= 0 else {
            throw MotiveLevelsError.invalidElapsedSeconds
        }

        let remainingSeconds = action.offer.durationSeconds - action.elapsedSeconds
        let activeSeconds = min(elapsedSeconds, remainingSeconds)
        let nextElapsedSeconds = action.elapsedSeconds + activeSeconds
        let nextStatus: InteractionActionStatus =
            nextElapsedSeconds >= action.offer.durationSeconds ? .completed : .running
        let nextMotives = try MotiveSystem.fulfill(
            motives,
            with: action.offer.motiveEffects,
            overSeconds: activeSeconds
        )

        return InteractionActionUpdate(
            action: InteractionActionState(
                offer: action.offer,
                initiator: action.initiator,
                elapsedSeconds: nextElapsedSeconds,
                status: nextStatus
            ),
            motives: nextMotives
        )
    }

    /// Stops a running action without undoing effects already applied.
    public static func interrupt(
        _ action: InteractionActionState,
        because reason: InteractionActionInterruptionReason
    ) throws -> InteractionActionState {
        try terminating(action, with: .interrupted(reason))
    }

    /// Marks a running action as failed without undoing effects already applied.
    public static func fail(
        _ action: InteractionActionState,
        because reason: InteractionActionFailureReason
    ) throws -> InteractionActionState {
        try terminating(action, with: .failed(reason))
    }

    private static func terminating(
        _ action: InteractionActionState,
        with status: InteractionActionStatus
    ) throws -> InteractionActionState {
        guard action.status == .running else {
            throw InteractionActionError.actionIsNotRunning
        }
        return InteractionActionState(
            offer: action.offer,
            initiator: action.initiator,
            elapsedSeconds: action.elapsedSeconds,
            status: status
        )
    }
}
