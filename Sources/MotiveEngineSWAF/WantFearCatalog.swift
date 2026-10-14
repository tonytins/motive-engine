import Foundation
import MotiveEngine

/// A game-defined label that shapes which wants and fears a Sim rolls.
///
/// Tags stand in for aspirations, life stages, traits, hobbies, seasons, and
/// recent events, such as `aspiration:romance` or `stage:teen`. The engine
/// only compares tags; their meaning belongs to the game.
public struct SWAFTag: StringIdentifier {
    /// The game-defined label.
    public let rawValue: String

    /// Creates a tag from a nonempty string.
    public init?(_ rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
}

/// A stable identifier for one want or fear definition.
public struct WantFearID: StringIdentifier {
    /// The content-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty string.
    public init?(_ rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
}

/// A stable identifier for an event the game reports, such as a promotion.
public struct GameEventID: StringIdentifier {
    /// The game-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty string.
    public init?(_ rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
}

/// Whether an entry is something a Sim wants or something it fears.
public enum WantFearKind: String, Codable, Sendable {
    /// Fulfilling it raises aspiration and earns reward points.
    case want

    /// Realizing it lowers aspiration and costs reward points.
    case fear
}

/// What causes a want to be fulfilled or a fear to be realized.
public enum WantFearTrigger: Equatable, Sendable {
    /// The game reports the named event for the Sim.
    case gameEvent(GameEventID)

    /// The Sim completes an interaction.
    ///
    /// A `nil` identifier matches any value; at least one must be supplied.
    case interactionCompleted(
        itemDefinitionID: ItemDefinitionID?,
        interactionDefinitionID: InteractionDefinitionID?
    )

    /// The Sim's motive is below the level when its wants and fears are checked.
    case motiveBelow(MotiveType, level: Double)
}

/// Reusable content for one want or fear.
public struct WantFearDefinition: Equatable, Sendable {
    /// The stable identifier.
    public let id: WantFearID

    /// Whether this is a want or a fear.
    public let kind: WantFearKind

    /// The player-facing description.
    public let name: String

    /// What fulfills the want or realizes the fear.
    public let trigger: WantFearTrigger

    /// Tags a Sim must have for this entry to be rolled.
    public let requiredTags: Set<SWAFTag>

    /// The roll weight before tag and motive adjustments.
    public let baseWeight: Double

    /// Weight added for each tag the Sim has. Negative values discourage.
    public let tagWeights: [SWAFTag: Double]

    /// Weight added per motive, scaled by that motive's urgency.
    ///
    /// Urgency is `(100 - level) / 100`, as in autonomy scoring, so a tired
    /// Sim is more likely to roll an entry weighted toward energy.
    public let motiveWeights: [MotiveType: Double]

    /// Aspiration gained for a want or lost for a fear, from 0 to 100.
    public let aspirationPoints: Double

    /// Reward points earned for a want or lost for a fear.
    public let rewardPoints: Int

    /// Creates validated want or fear content.
    ///
    /// - Throws: `WantFearDefinitionError` for an empty name, an
    ///   interaction trigger without identifiers, a motive level outside
    ///   `0...100`, non-finite or negative base weight, non-finite tag or
    ///   motive weights, or out-of-range points.
    public init(
        id: WantFearID,
        kind: WantFearKind,
        name: String,
        trigger: WantFearTrigger,
        requiredTags: Set<SWAFTag> = [],
        baseWeight: Double = 1,
        tagWeights: [SWAFTag: Double] = [:],
        motiveWeights: [MotiveType: Double] = [:],
        aspirationPoints: Double,
        rewardPoints: Int
    ) throws {
        guard !name.isEmpty else {
            throw WantFearDefinitionError.emptyName(id)
        }
        switch trigger {
        case .gameEvent:
            break
        case let .interactionCompleted(itemDefinitionID, interactionDefinitionID):
            guard itemDefinitionID != nil || interactionDefinitionID != nil else {
                throw WantFearDefinitionError.invalidTrigger(id)
            }
        case let .motiveBelow(_, level):
            guard level.isFinite, (MotiveLevels.minimumValue ... MotiveLevels.maximumValue).contains(level) else {
                throw WantFearDefinitionError.invalidTrigger(id)
            }
        }
        guard baseWeight.isFinite, baseWeight >= 0,
              tagWeights.values.allSatisfy(\.isFinite),
              motiveWeights.values.allSatisfy(\.isFinite)
        else {
            throw WantFearDefinitionError.invalidWeight(id)
        }
        guard aspirationPoints.isFinite,
              (0 ... AspirationState.maximumAspiration).contains(aspirationPoints)
        else {
            throw WantFearDefinitionError.invalidAspirationPoints(id)
        }
        guard rewardPoints >= 0 else {
            throw WantFearDefinitionError.invalidRewardPoints(id)
        }

        self.id = id
        self.kind = kind
        self.name = name
        self.trigger = trigger
        self.requiredTags = requiredTags
        self.baseWeight = baseWeight
        self.tagWeights = tagWeights
        self.motiveWeights = motiveWeights
        self.aspirationPoints = aspirationPoints
        self.rewardPoints = rewardPoints
    }

    /// The roll weight for a Sim, or zero when the entry cannot be rolled.
    ///
    /// The weight is the base weight, plus the weight of each tag the Sim
    /// has, plus each motive weight multiplied by that motive's urgency.
    /// Missing required tags or a total at or below zero yield zero.
    public func rollWeight(tags: Set<SWAFTag>, motives: MotiveLevels) -> Double {
        guard requiredTags.isSubset(of: tags) else {
            return 0
        }
        var weight = baseWeight
        for (tag, tagWeight) in tagWeights where tags.contains(tag) {
            weight += tagWeight
        }
        for (motiveType, motiveWeight) in motiveWeights {
            let urgency = (MotiveLevels.maximumValue - motives.level(for: motiveType))
                / MotiveLevels.maximumValue
            weight += motiveWeight * urgency
        }
        return weight.isFinite && weight > 0 ? weight : 0
    }
}

/// Invalid want or fear content.
public enum WantFearDefinitionError: Error, Equatable, Sendable {
    /// The player-facing name is empty.
    case emptyName(WantFearID)

    /// The trigger cannot match anything or has an invalid motive level.
    case invalidTrigger(WantFearID)

    /// A weight is non-finite, or the base weight is negative.
    case invalidWeight(WantFearID)

    /// Aspiration points are non-finite or outside `0...100`.
    case invalidAspirationPoints(WantFearID)

    /// Reward points are negative.
    case invalidRewardPoints(WantFearID)
}

/// An invalid want and fear catalog.
public enum WantFearCatalogError: Error, Equatable, Sendable {
    /// Two definitions use the same identifier.
    case duplicateID(WantFearID)

    /// A JSON motive weight or trigger names an unknown motive.
    case unknownMotive(String)
}

/// Reusable want and fear definitions indexed by stable ID.
public struct WantFearCatalog: Sendable {
    private let definitionsByID: [WantFearID: WantFearDefinition]

    /// All definitions sorted by ID.
    public let definitions: [WantFearDefinition]

    /// Creates a catalog and rejects duplicate IDs.
    public init(definitions: [WantFearDefinition]) throws {
        var definitionsByID: [WantFearID: WantFearDefinition] = [:]
        for definition in definitions {
            guard definitionsByID.updateValue(definition, forKey: definition.id) == nil else {
                throw WantFearCatalogError.duplicateID(definition.id)
            }
        }
        self.definitionsByID = definitionsByID
        self.definitions = definitions.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    /// Decodes a catalog from JSON matching `schema/swaf.json`.
    ///
    /// - Throws: `DecodingError` for malformed JSON, `WantFearCatalogError`
    ///   for unknown motives or duplicate IDs, and
    ///   `WantFearDefinitionError` for invalid content.
    public init(jsonData: Data) throws {
        let payload = try JSONDecoder().decode(CatalogPayload.self, from: jsonData)
        try self.init(definitions: payload.entries.map { try $0.definition() })
    }

    /// Returns the definition with the specified ID, if present.
    public func definition(for id: WantFearID) -> WantFearDefinition? {
        definitionsByID[id]
    }
}

private struct CatalogPayload: Decodable {
    let entries: [EntryPayload]
}

private struct EntryPayload: Decodable {
    struct TriggerPayload: Decodable {
        struct Interaction: Decodable {
            let itemDefinition: ItemDefinitionID?
            let interaction: InteractionDefinitionID?
        }

        struct MotiveThreshold: Decodable {
            let motive: String
            let level: Double
        }

        let event: GameEventID?
        let interactionCompleted: Interaction?
        let motiveBelow: MotiveThreshold?
    }

    let id: WantFearID
    let kind: WantFearKind
    let name: String
    let trigger: TriggerPayload
    let requiredTags: Set<SWAFTag>?
    let weight: Double?
    let tagWeights: [String: Double]?
    let motiveWeights: [String: Double]?
    let aspiration: Double
    let rewardPoints: Int

    func definition() throws -> WantFearDefinition {
        var tagWeightsByTag: [SWAFTag: Double] = [:]
        for (rawTag, tagWeight) in tagWeights ?? [:] {
            guard let tag = SWAFTag(rawTag) else {
                throw WantFearDefinitionError.invalidWeight(id)
            }
            tagWeightsByTag[tag] = tagWeight
        }
        var motiveWeightsByType: [MotiveType: Double] = [:]
        for (rawMotive, motiveWeight) in motiveWeights ?? [:] {
            motiveWeightsByType[try Self.motiveType(rawMotive)] = motiveWeight
        }

        return try WantFearDefinition(
            id: id,
            kind: kind,
            name: name,
            trigger: resolvedTrigger(),
            requiredTags: requiredTags ?? [],
            baseWeight: weight ?? 1,
            tagWeights: tagWeightsByTag,
            motiveWeights: motiveWeightsByType,
            aspirationPoints: aspiration,
            rewardPoints: rewardPoints
        )
    }

    private func resolvedTrigger() throws -> WantFearTrigger {
        switch (trigger.event, trigger.interactionCompleted, trigger.motiveBelow) {
        case let (event?, nil, nil):
            return .gameEvent(event)
        case let (nil, interaction?, nil):
            return .interactionCompleted(
                itemDefinitionID: interaction.itemDefinition,
                interactionDefinitionID: interaction.interaction
            )
        case let (nil, nil, threshold?):
            return try .motiveBelow(Self.motiveType(threshold.motive), level: threshold.level)
        default:
            throw WantFearDefinitionError.invalidTrigger(id)
        }
    }

    private static func motiveType(_ rawValue: String) throws -> MotiveType {
        guard let motiveType = MotiveType(rawValue: rawValue) else {
            throw WantFearCatalogError.unknownMotive(rawValue)
        }
        return motiveType
    }
}
