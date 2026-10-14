/// The actor data used to evaluate whether an interaction can start.
public struct InteractionActorSnapshot: Equatable, Sendable {
    /// The actor's current posture.
    public let posture: SimPosture

    /// Whether the actor can begin another interaction.
    public let isAvailable: Bool

    /// Creates an actor snapshot for interaction eligibility.
    public init(posture: SimPosture, isAvailable: Bool) {
        self.posture = posture
        self.isAvailable = isAvailable
    }
}

/// The item-instance data used to evaluate interaction availability.
public struct InteractionItemSnapshot: Equatable, Sendable {
    /// The placed item instance represented by this snapshot.
    public let itemInstanceID: ItemInstanceID

    /// Whether the item can currently be used.
    public let isAvailable: Bool

    /// The number of actors the item can support at once.
    public let capacity: Int

    /// The number of actors currently using the item.
    public let occupancy: Int

    /// Creates an item snapshot with explicit capacity and occupancy.
    ///
    /// A zero capacity represents an item that currently has no usable
    /// interaction slots.
    ///
    /// - Throws: `InteractionItemSnapshotError` if capacity or occupancy
    ///   is negative.
    public init(
        itemInstanceID: ItemInstanceID,
        isAvailable: Bool,
        capacity: Int,
        occupancy: Int
    ) throws {
        guard capacity >= 0 else {
            throw InteractionItemSnapshotError.negativeCapacity
        }
        guard occupancy >= 0 else {
            throw InteractionItemSnapshotError.negativeOccupancy
        }

        self.itemInstanceID = itemInstanceID
        self.isAvailable = isAvailable
        self.capacity = capacity
        self.occupancy = occupancy
    }
}

/// An invalid value supplied for item interaction availability.
public enum InteractionItemSnapshotError: Error, Equatable, Sendable {
    /// Capacity cannot be negative.
    case negativeCapacity

    /// Occupancy cannot be negative.
    case negativeOccupancy
}

/// A reason that an interaction offer cannot currently be started.
public enum InteractionIneligibilityReason: Equatable, Sendable {
    /// Actor state was not supplied.
    case missingActorSnapshot

    /// The actor is already unavailable for another interaction.
    case actorUnavailable

    /// The actor does not have the required posture.
    case postureMismatch(required: SimPosture, actual: SimPosture)

    /// Item state was not supplied.
    case missingItemSnapshot

    /// The supplied item snapshot belongs to another placed instance.
    case itemSnapshotMismatch(expected: ItemInstanceID, actual: ItemInstanceID)

    /// The item is not currently usable.
    case itemUnavailable

    /// All interaction slots are occupied.
    case itemAtCapacity(capacity: Int, occupancy: Int)
}

/// The result of evaluating an interaction offer against current snapshots.
public struct InteractionEligibility: Equatable, Sendable {
    /// Reasons this offer cannot currently be started.
    public let reasons: [InteractionIneligibilityReason]

    /// Whether all supplied requirements are satisfied.
    public var isEligible: Bool {
        reasons.isEmpty
    }

    fileprivate init(reasons: [InteractionIneligibilityReason]) {
        self.reasons = reasons
    }
}

/// Pure interaction eligibility checks over an offer and explicit snapshots.
public enum InteractionEligibilitySystem {
    /// Evaluates an offer, reporting all unmet requirements in stable order.
    public static func evaluate(
        _ offer: InteractionOffer,
        actor: InteractionActorSnapshot?,
        item: InteractionItemSnapshot?
    ) -> InteractionEligibility {
        var reasons: [InteractionIneligibilityReason] = []

        if let actor {
            if !actor.isAvailable {
                reasons.append(.actorUnavailable)
            }
            if let requiredPosture = offer.requirements.requiredPosture,
               actor.posture != requiredPosture
            {
                reasons.append(
                    .postureMismatch(required: requiredPosture, actual: actor.posture),
                )
            }
        } else {
            reasons.append(.missingActorSnapshot)
        }

        if let item, item.itemInstanceID == offer.itemInstanceID {
            if !item.isAvailable {
                reasons.append(.itemUnavailable)
            }
            if item.occupancy >= item.capacity {
                reasons.append(
                    .itemAtCapacity(capacity: item.capacity, occupancy: item.occupancy),
                )
            }
        } else if let item {
            reasons.append(
                .itemSnapshotMismatch(
                    expected: offer.itemInstanceID,
                    actual: item.itemInstanceID,
                ),
            )
        } else {
            reasons.append(.missingItemSnapshot)
        }

        return InteractionEligibility(reasons: reasons)
    }
}
