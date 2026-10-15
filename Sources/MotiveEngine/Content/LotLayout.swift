import Foundation

/// The starting point for one lot: its size, where items go, and the Sims who
/// live there.
///
/// Items are placed by qualified definition ID, such as `base:fridge`, so a
/// layout works with whatever content packs a game loads. A layout is the
/// editable source a game or modder writes; it is not a save of a running
/// simulation.
///
/// The JSON form is described by `schema/lot.json`.
public struct LotLayout: Equatable, Sendable {
    /// One item placed on the lot.
    public struct ItemPlacement: Equatable, Sendable {
        /// The placed instance's identity.
        public let id: ItemInstanceID

        /// The content the item uses.
        public let definitionID: ItemDefinitionID

        /// Where the item sits.
        public let position: GridPosition

        /// Creates a placement.
        public init(id: ItemInstanceID, definitionID: ItemDefinitionID, position: GridPosition) {
            self.id = id
            self.definitionID = definitionID
            self.position = position
        }
    }

    /// One Sim who starts on the lot.
    public struct SimPlacement: Equatable, Sendable {
        /// The Sim's identity.
        public let id: SimID

        /// The name players see. The engine itself doesn't use it.
        public let name: String

        /// Where the Sim starts.
        public let position: GridPosition

        /// The Sim's starting motive levels.
        public let motives: MotiveLevels

        /// Creates a Sim placement.
        public init(id: SimID, name: String, position: GridPosition, motives: MotiveLevels) {
            self.id = id
            self.name = name
            self.position = position
            self.motives = motives
        }
    }

    /// The lot's grid size.
    public let size: GridSize

    /// The household every Sim on the lot belongs to, if any.
    public let householdID: HouseholdID?

    /// Item placements, in the order written.
    public let items: [ItemPlacement]

    /// Sims, in the order written.
    public let sims: [SimPlacement]

    /// Creates a validated layout.
    ///
    /// Positions are checked against the size, and Sims against items, when
    /// the layout becomes a `SimulationState`.
    ///
    /// - Throws: `LotLayoutError` for a size that isn't positive, a duplicate
    ///   item or Sim ID, or an empty Sim name.
    public init(
        size: GridSize,
        householdID: HouseholdID? = nil,
        items: [ItemPlacement],
        sims: [SimPlacement]
    ) throws {
        guard size.width > 0, size.height > 0 else {
            throw LotLayoutError.invalidSize
        }
        var itemIDs: Set<ItemInstanceID> = []
        for item in items where !itemIDs.insert(item.id).inserted {
            throw LotLayoutError.duplicateItem(item.id)
        }
        var simIDs: Set<SimID> = []
        for sim in sims {
            guard simIDs.insert(sim.id).inserted else {
                throw LotLayoutError.duplicateSim(sim.id)
            }
            guard !sim.name.isEmpty else {
                throw LotLayoutError.emptyName(sim.id)
            }
        }

        self.size = size
        self.householdID = householdID
        self.items = items
        self.sims = sims
    }

    /// Decodes and validates a layout from JSON matching `schema/lot.json`.
    ///
    /// - Throws: `DecodingError` for malformed JSON, `LotLayoutError` for
    ///   invalid values or an unknown motive name, and `MotiveLevelsError` for
    ///   missing or non-finite motive levels.
    public init(jsonData: Data) throws {
        let payload = try JSONDecoder().decode(LotLayoutPayload.self, from: jsonData)
        try self.init(
            size: GridSize(width: payload.width, height: payload.height),
            householdID: payload.household,
            items: payload.items.map {
                ItemPlacement(id: $0.id, definitionID: $0.definition, position: GridPosition(x: $0.x, y: $0.y))
            },
            sims: payload.sims.map { sim in
                SimPlacement(
                    id: sim.id,
                    name: sim.name,
                    position: GridPosition(x: sim.x, y: sim.y),
                    motives: try Self.motiveLevels(sim.motives, for: sim.id)
                )
            }
        )
    }

    /// Builds a validated world from the layout.
    ///
    /// Every Sim starts standing, on the lot, in the layout's household.
    ///
    /// - Parameters:
    ///   - lotID: The identity to give the lot.
    ///   - catalog: The content the placements refer to.
    ///   - missingContent: Whether a placement whose definition isn't in the
    ///     catalog is an error (the default) or is skipped and reported.
    /// - Throws: `LotLayoutError.missingDefinition` under `.reject`, and
    ///   `LotStateError`, `HouseholdStateError`, or `SimulationStateError` when
    ///   positions fall outside the lot or Sims overlap.
    public func makeState(
        lotID: LotID,
        catalog: ItemDefinitionCatalog,
        missingContent: MissingContentPolicy = .reject
    ) throws -> LotLayoutResult {
        var placedItems: [PlacedItem] = []
        var skippedItems: [ItemPlacement] = []
        for item in items {
            guard catalog.definition(for: item.definitionID) != nil else {
                guard missingContent == .skip else {
                    throw LotLayoutError.missingDefinition(item.definitionID)
                }
                skippedItems.append(item)
                continue
            }
            placedItems.append(PlacedItem(id: item.id, definitionID: item.definitionID, position: item.position))
        }

        let simStates = sims.map {
            SimStateData(id: $0.id, motives: $0.motives, posture: .standing, currentLotID: lotID, position: $0.position)
        }
        let households = try householdID.map {
            [try HouseholdState(id: $0, memberIDs: sims.map(\.id))]
        } ?? []
        let state = try SimulationState(
            sims: simStates,
            households: households,
            lots: [LotState(id: lotID, bounds: size, placedItems: placedItems)]
        )
        return LotLayoutResult(state: state, skippedItems: skippedItems)
    }

    private static func motiveLevels(_ values: [String: Double], for simID: SimID) throws -> MotiveLevels {
        var levels: [MotiveType: Double] = [:]
        for (name, value) in values {
            guard let motiveType = MotiveType(rawValue: name) else {
                throw LotLayoutError.unknownMotive(simID: simID, motive: name)
            }
            levels[motiveType] = value
        }
        return try MotiveLevels(levels: levels)
    }
}

/// What to do with a layout placement whose content isn't loaded.
public enum MissingContentPolicy: Equatable, Sendable {
    /// Building the world fails.
    case reject

    /// The placement is left off the lot and reported in the result.
    case skip
}

/// A world built from a lot layout.
public struct LotLayoutResult: Equatable, Sendable {
    /// The validated world.
    public let state: SimulationState

    /// Placements left off because their content isn't loaded. Always empty
    /// under `MissingContentPolicy.reject`.
    public let skippedItems: [LotLayout.ItemPlacement]
}

/// An invalid lot layout.
public enum LotLayoutError: Error, Equatable, Sendable {
    /// The width or height isn't positive.
    case invalidSize

    /// Two items use the same ID.
    case duplicateItem(ItemInstanceID)

    /// Two Sims use the same ID.
    case duplicateSim(SimID)

    /// A Sim's name is empty.
    case emptyName(SimID)

    /// A Sim's motives name a motive the engine doesn't define.
    case unknownMotive(simID: SimID, motive: String)

    /// A placement's definition isn't in the catalog.
    case missingDefinition(ItemDefinitionID)
}

private struct LotLayoutPayload: Decodable {
    struct Item: Decodable {
        let id: ItemInstanceID
        let definition: ItemDefinitionID
        let x: Int
        let y: Int
    }

    struct Sim: Decodable {
        let id: SimID
        let name: String
        let x: Int
        let y: Int
        let motives: [String: Double]
    }

    let width: Int
    let height: Int
    let household: HouseholdID?
    let items: [Item]
    let sims: [Sim]
}
