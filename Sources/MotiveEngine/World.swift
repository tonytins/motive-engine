import Foundation

/// A stable identifier for one Sim in a simulation.
public struct SimID: Codable, Hashable, Sendable {
    /// The game-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty string.
    public init?(_ rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard !rawValue.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Sim ID must not be empty",
            )
        }
        self.rawValue = rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A stable identifier for one household in a simulation.
public struct HouseholdID: Codable, Hashable, Sendable {
    /// The game-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty string.
    public init?(_ rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard !rawValue.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Household ID must not be empty",
            )
        }
        self.rawValue = rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A stable identifier for one lot in a simulation.
public struct LotID: Codable, Hashable, Sendable {
    /// The game-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty string.
    public init?(_ rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard !rawValue.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Lot ID must not be empty",
            )
        }
        self.rawValue = rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// The mutable value data for one Sim.
public struct SimStateData: Equatable, Sendable {
    /// The Sim's stable identity.
    public let id: SimID

    /// The Sim's current motive values.
    public let motives: MotiveLevels

    /// The Sim's current posture.
    public let posture: SimPosture

    /// The lot the Sim currently occupies, if any.
    public let currentLotID: LotID?

    /// The Sim's current grid position on its lot, if present.
    public let position: GridPosition?

    /// The interaction the Sim is currently executing, if any.
    public let activeAction: InteractionActionState?

    /// Creates state for one Sim.
    public init(
        id: SimID,
        motives: MotiveLevels,
        posture: SimPosture,
        currentLotID: LotID? = nil,
        position: GridPosition? = nil,
        activeAction: InteractionActionState? = nil
    ) {
        self.id = id
        self.motives = motives
        self.posture = posture
        self.currentLotID = currentLotID
        self.position = position
        self.activeAction = activeAction
    }
}

/// The member identities for one household.
public struct HouseholdState: Equatable, Sendable {
    /// The household's stable identity.
    public let id: HouseholdID

    /// The Sims belonging to this household.
    public let memberIDs: [SimID]

    /// Creates household data and rejects duplicate members.
    ///
    /// - Throws: `HouseholdStateError.duplicateMember` if an identity occurs
    ///   more than once.
    public init(id: HouseholdID, memberIDs: [SimID]) throws {
        var seenMemberIDs: Set<SimID> = []
        for memberID in memberIDs {
            guard seenMemberIDs.insert(memberID).inserted else {
                throw HouseholdStateError.duplicateMember(householdID: id, simID: memberID)
            }
        }

        self.id = id
        self.memberIDs = memberIDs
    }
}

/// An invalid household value.
public enum HouseholdStateError: Error, Equatable, Sendable {
    /// A Sim appears more than once in one household.
    case duplicateMember(householdID: HouseholdID, simID: SimID)
}

/// The dimensions and item placements for one lot.
public struct LotState: Equatable, Sendable {
    /// The lot's stable identity.
    public let id: LotID

    /// The lot's rectangular grid bounds.
    public let bounds: GridSize

    /// The item instances placed on this lot.
    public let placedItems: [PlacedItem]

    /// Creates a lot and validates its bounds and item placements.
    ///
    /// - Throws: `LotStateError` if the dimensions are nonpositive, an item
    ///   lies outside the grid, or an item identity is duplicated.
    public init(id: LotID, bounds: GridSize, placedItems: [PlacedItem]) throws {
        guard bounds.width > 0, bounds.height > 0 else {
            throw LotStateError.invalidBounds
        }

        var seenItemIDs: Set<ItemInstanceID> = []
        for item in placedItems {
            guard bounds.contains(item.position) else {
                throw LotStateError.itemOutsideBounds(item.id)
            }
            guard seenItemIDs.insert(item.id).inserted else {
                throw LotStateError.duplicateItemID(item.id)
            }
        }

        self.id = id
        self.bounds = bounds
        self.placedItems = placedItems
    }
}

/// An invalid lot value.
public enum LotStateError: Error, Equatable, Sendable {
    /// A lot must have positive width and height.
    case invalidBounds

    /// An item position is outside the lot grid.
    case itemOutsideBounds(ItemInstanceID)

    /// An item identity occurs more than once on a lot.
    case duplicateItemID(ItemInstanceID)
}

/// An invalid relationship or identity in a simulation state.
public enum SimulationStateError: Error, Equatable, Sendable {
    /// Two Sim values use the same identity.
    case duplicateSimID(SimID)

    /// Two household values use the same identity.
    case duplicateHouseholdID(HouseholdID)

    /// Two lot values use the same identity.
    case duplicateLotID(LotID)

    /// A Sim refers to a lot that is not in the simulation.
    case missingCurrentLot(simID: SimID, lotID: LotID)

    /// A Sim occupies a lot without a grid position.
    case missingCurrentPosition(SimID)

    /// A Sim has a position but no current lot.
    case positionWithoutCurrentLot(SimID)

    /// A Sim position lies outside its current lot.
    case positionOutsideCurrentLot(simID: SimID, lotID: LotID)

    /// Two Sims occupy the same grid position on one lot.
    case duplicateSimPosition(lotID: LotID, position: GridPosition)

    /// A household refers to a Sim that is not in the simulation.
    case missingHouseholdMember(householdID: HouseholdID, simID: SimID)

    /// A Sim belongs to more than one household.
    case simInMultipleHouseholds(SimID)

    /// Placed item IDs must be unique across all lots.
    case duplicatePlacedItemID(ItemInstanceID)
}

/// The validated, ID-keyed entities in one simulation.
public struct SimulationState: Equatable, Sendable {
    /// Sim values keyed by stable Sim ID.
    public let sims: [SimID: SimStateData]

    /// Household values keyed by stable household ID.
    public let households: [HouseholdID: HouseholdState]

    /// Lot values keyed by stable lot ID.
    public let lots: [LotID: LotState]

    /// Creates a world state and validates entity identities and references.
    ///
    /// Household membership and current lot occupancy are independent.
    /// A household can have members on different lots, and a Sim may have
    /// no current lot.
    ///
    /// - Throws: `SimulationStateError` for duplicate entity IDs, missing
    ///   references, or invalid household membership.
    public init(
        sims: [SimStateData],
        households: [HouseholdState],
        lots: [LotState]
    ) throws {
        var simsByID: [SimID: SimStateData] = [:]
        for sim in sims {
            guard simsByID.updateValue(sim, forKey: sim.id) == nil else {
                throw SimulationStateError.duplicateSimID(sim.id)
            }
        }

        var householdsByID: [HouseholdID: HouseholdState] = [:]
        for household in households {
            guard householdsByID.updateValue(household, forKey: household.id) == nil else {
                throw SimulationStateError.duplicateHouseholdID(household.id)
            }
        }

        var lotsByID: [LotID: LotState] = [:]
        var placedItemIDs: Set<ItemInstanceID> = []
        for lot in lots {
            guard lotsByID.updateValue(lot, forKey: lot.id) == nil else {
                throw SimulationStateError.duplicateLotID(lot.id)
            }
            for item in lot.placedItems {
                guard placedItemIDs.insert(item.id).inserted else {
                    throw SimulationStateError.duplicatePlacedItemID(item.id)
                }
            }
        }

        var occupiedSimPositions: Set<SimOccupancyCell> = []
        for sim in sims {
            guard let lotID = sim.currentLotID else {
                guard sim.position == nil else {
                    throw SimulationStateError.positionWithoutCurrentLot(sim.id)
                }
                continue
            }
            guard let lot = lotsByID[lotID] else {
                throw SimulationStateError.missingCurrentLot(simID: sim.id, lotID: lotID)
            }
            guard let position = sim.position else {
                throw SimulationStateError.missingCurrentPosition(sim.id)
            }
            guard lot.bounds.contains(position) else {
                throw SimulationStateError.positionOutsideCurrentLot(
                    simID: sim.id,
                    lotID: lotID
                )
            }
            guard occupiedSimPositions.insert(
                SimOccupancyCell(lotID: lotID, position: position)
            ).inserted else {
                throw SimulationStateError.duplicateSimPosition(
                    lotID: lotID,
                    position: position
                )
            }
        }

        var householdIDsBySimID: [SimID: HouseholdID] = [:]
        for household in households {
            for memberID in household.memberIDs {
                guard simsByID[memberID] != nil else {
                    throw SimulationStateError.missingHouseholdMember(
                        householdID: household.id,
                        simID: memberID
                    )
                }
                guard householdIDsBySimID.updateValue(household.id, forKey: memberID) == nil else {
                    throw SimulationStateError.simInMultipleHouseholds(memberID)
                }
            }
        }

        self.sims = simsByID
        self.households = householdsByID
        self.lots = lotsByID
    }

    /// Returns the Sim value for an identity, if present.
    public func sim(for id: SimID) -> SimStateData? {
        sims[id]
    }

    /// Returns the household value for an identity, if present.
    public func household(for id: HouseholdID) -> HouseholdState? {
        households[id]
    }

    /// Returns the lot value for an identity, if present.
    public func lot(for id: LotID) -> LotState? {
        lots[id]
    }
}

private struct SimOccupancyCell: Hashable {
    let lotID: LotID
    let position: GridPosition
}
