
let motiveStrengthScale = 25.0

/// A behavior an item has, such as being a bed or giving off ambience.
///
/// An item can carry several modifiers. They decide whether the item blocks
/// movement by default.
public enum ItemModifier: String, CaseIterable, Hashable, Codable, Sendable {
    case appliance
    case bed
    case shower
    case toilet
    case recreation
    case sim
    case ambient
    case chair
    case skill

    var isBlockingByDefault: Bool {
        switch self {
        case .appliance, .bed, .shower, .toilet, .recreation, .chair, .skill:
            true
        case .sim, .ambient:
            false
        }
    }

    var grantsSittingPosture: Bool {
        switch self {
        case .chair, .toilet:
            true
        default:
            false
        }
    }

    /// The modifiers a Sim in the given posture can also use alongside this item.
    func delegatedModifiers(for posture: SimPosture) -> Set<ItemModifier> {
        switch self {
        case .chair:
            [.recreation, .sim]
        case .recreation, .appliance:
            posture == .standing ? [.sim] : []
        default:
            []
        }
    }

    /// Decodes either one modifier or a nonempty array of modifiers.
    static func decodedSet<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Set<ItemModifier> {
        guard let modifiers = try? container.decode([ItemModifier].self, forKey: key) else {
            return try [container.decode(ItemModifier.self, forKey: key)]
        }
        guard !modifiers.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Item must contain at least one type"
            )
        }
        return Set(modifiers)
    }
}

/// The name, modifiers, and blocking behavior shared by an item's instances.
public struct ItemIdentity: Equatable, Sendable {
    /// The player-facing name.
    public let name: String

    /// The item's modifiers.
    public let itemTypes: Set<ItemModifier>

    /// Whether the item's tile blocks movement.
    public let isBlocking: Bool

    /// Creates an identity.
    ///
    /// When `isBlocking` is `nil`, the item blocks movement if any of its
    /// modifiers blocks by default.
    public init(
        name: String,
        itemTypes: some Sequence<ItemModifier>,
        isBlocking: Bool? = nil
    ) {
        let modifiers = Set(itemTypes)
        self.name = name
        self.itemTypes = modifiers
        self.isBlocking = isBlocking ?? modifiers.contains { $0.isBlockingByDefault }
    }

    /// Creates an identity with a single modifier and default blocking.
    public init(name: String, itemTypes: ItemModifier) {
        self.init(name: name, itemTypes: [itemTypes])
    }
}

/// A stable identifier for reusable item content.
public struct ItemDefinitionID: StringIdentifier {
    /// The content-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty, content-defined string.
    ///
    /// - Returns: `nil` when `rawValue` is empty.
    public init?(_ rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
}

/// A stable identifier for one placed item instance.
public struct ItemInstanceID: StringIdentifier {
    /// The game-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty, game-defined string.
    ///
    /// - Returns: `nil` when `rawValue` is empty.
    public init?(_ rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
}

/// A stable identifier for an interaction within item content.
public struct InteractionDefinitionID: StringIdentifier {
    /// The content-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty, content-defined string.
    ///
    /// - Returns: `nil` when `rawValue` is empty.
    public init?(_ rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }
}

/// Requirements that must be met to start an interaction.
public struct InteractionRequirements: Equatable, Sendable {
    /// The actor posture required by the interaction, if any.
    public let requiredPosture: SimPosture?

    /// Creates interaction requirements.
    public init(requiredPosture: SimPosture? = nil) {
        self.requiredPosture = requiredPosture
    }
}

/// Reusable interaction content with separate advertised benefits and effects.
public struct InteractionDefinition: Equatable, Sendable {
    /// The stable identifier within its item definition.
    public let id: InteractionDefinitionID

    /// The player-facing name of the interaction.
    public let name: String

    /// Expected motive changes used to evaluate this interaction.
    public let advertisedBenefits: [MotiveBenefit]

    /// Motive changes applied while the interaction executes.
    public let motiveEffects: [MotiveSignal]

    /// The interaction's active duration in simulated seconds.
    public let durationSeconds: Double

    /// Preconditions declared by the interaction.
    public let requirements: InteractionRequirements

    /// A script that computes the applied effects when an action starts.
    ///
    /// When present, its effects replace `motiveEffects`.
    public let script: InteractionScript?

    /// Creates interaction content with explicit advertised and applied values.
    ///
    /// - Throws: `InteractionDefinitionError` when the name is empty, the
    ///   duration is not positive and finite, or a strength is not finite.
    public init(
        id: InteractionDefinitionID,
        name: String,
        advertisedBenefits: [MotiveBenefit],
        motiveEffects: [MotiveSignal],
        durationSeconds: Double,
        requirements: InteractionRequirements = InteractionRequirements(),
        script: InteractionScript? = nil
    ) throws {
        guard !name.isEmpty else {
            throw InteractionDefinitionError.emptyName
        }
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw InteractionDefinitionError.invalidDuration
        }
        for benefit in advertisedBenefits where !benefit.expectedStrengthPerSecond.isFinite {
            throw InteractionDefinitionError.nonFiniteAdvertisedBenefit(benefit.motiveType)
        }
        for effect in motiveEffects where !effect.strengthPerSecond.isFinite {
            throw InteractionDefinitionError.nonFiniteMotiveEffect(effect.motiveType)
        }

        self.id = id
        self.name = name
        self.advertisedBenefits = advertisedBenefits
        self.motiveEffects = motiveEffects
        self.durationSeconds = durationSeconds
        self.requirements = requirements
        self.script = script
    }
}

/// An error encountered while creating an interaction definition.
public enum InteractionDefinitionError: Error, Equatable, Sendable {
    /// The interaction name is empty.
    case emptyName

    /// The interaction duration is not positive and finite.
    case invalidDuration

    /// An advertised benefit has a non-finite strength.
    case nonFiniteAdvertisedBenefit(MotiveType)

    /// A motive effect has a non-finite strength.
    case nonFiniteMotiveEffect(MotiveType)
}

/// One item instance's interaction candidate, ready for eligibility checks.
public struct InteractionOffer: Equatable, Sendable {
    /// The item instance that provides this interaction.
    public let itemInstanceID: ItemInstanceID

    /// The definition that provides this interaction.
    public let itemDefinitionID: ItemDefinitionID

    /// The offered interaction definition.
    public let interactionDefinitionID: InteractionDefinitionID

    /// The player-facing interaction name.
    public let name: String

    /// Expected motive changes. These are not applied by the offer.
    public let advertisedBenefits: [MotiveBenefit]

    /// Motive changes applied while the action is active, unless `script` replaces them.
    public let motiveEffects: [MotiveSignal]

    /// The interaction's active duration in simulated seconds.
    public let durationSeconds: Double

    /// Preconditions declared by the interaction.
    public let requirements: InteractionRequirements

    /// A script that computes the applied effects when an action starts.
    public let script: InteractionScript?

    fileprivate init(
        itemInstanceID: ItemInstanceID,
        itemDefinitionID: ItemDefinitionID,
        interaction: InteractionDefinition
    ) {
        self.itemInstanceID = itemInstanceID
        self.itemDefinitionID = itemDefinitionID
        interactionDefinitionID = interaction.id
        name = interaction.name
        advertisedBenefits = interaction.advertisedBenefits
        motiveEffects = interaction.motiveEffects
        durationSeconds = interaction.durationSeconds
        requirements = interaction.requirements
        script = interaction.script
    }
}

/// Reusable item content, separate from any placed item instance.
public struct ItemDefinition: Broadcasting, Equatable, Sendable {
    /// The stable identifier used by placed instances.
    public let id: ItemDefinitionID

    /// The name, item modifiers, and blocking behavior shared by instances.
    public let identity: ItemIdentity

    /// The motive signals offered by this item content.
    public let signals: [MotiveSignal]

    /// The selectable interactions defined by this item content.
    public let interactions: [InteractionDefinition]

    /// The number of Sims that can reserve interactions on this item at once.
    public let interactionCapacity: Int

    /// Creates reusable item content with an explicit stable identifier.
    ///
    /// - Throws: `ItemDefinitionError.invalidInteractionCapacity` when the
    ///   capacity is not positive.
    public init(
        id: ItemDefinitionID,
        identity: ItemIdentity,
        signals: [MotiveSignal],
        interactions: [InteractionDefinition] = [],
        interactionCapacity: Int = 1
    ) throws {
        guard interactionCapacity > 0 else {
            throw ItemDefinitionError.invalidInteractionCapacity
        }

        self.id = id
        self.identity = identity
        self.signals = signals
        self.interactions = interactions
        self.interactionCapacity = interactionCapacity
    }
}

/// An invalid item definition.
public enum ItemDefinitionError: Error, Equatable, Sendable {
    /// Interaction capacity must be positive.
    case invalidInteractionCapacity
}

/// An error produced while building an item definition catalog.
public enum ItemDefinitionCatalogError: Error, Equatable, Sendable {
    /// Two definitions use the same identifier.
    case duplicateDefinitionID(ItemDefinitionID)

    /// Two interactions within one definition use the same identifier.
    case duplicateInteractionDefinitionID(ItemDefinitionID, InteractionDefinitionID)

    /// A placed item references a definition that is not in the catalog.
    case missingDefinition(ItemDefinitionID)
}

/// Reusable item definitions indexed by their stable content IDs.
public struct ItemDefinitionCatalog: Sendable {
    private let definitionsByID: [ItemDefinitionID: ItemDefinition]

    /// Creates a catalog and rejects duplicate definition IDs.
    public init(definitions: [ItemDefinition]) throws {
        var definitionsByID: [ItemDefinitionID: ItemDefinition] = [:]
        for definition in definitions {
            guard definitionsByID[definition.id] == nil else {
                throw ItemDefinitionCatalogError.duplicateDefinitionID(definition.id)
            }
            var interactionIDs: Set<InteractionDefinitionID> = []
            for interaction in definition.interactions {
                guard interactionIDs.insert(interaction.id).inserted else {
                    throw ItemDefinitionCatalogError.duplicateInteractionDefinitionID(
                        definition.id,
                        interaction.id,
                    )
                }
            }
            definitionsByID[definition.id] = definition
        }
        self.definitionsByID = definitionsByID
    }

    /// Returns the definition with the specified ID, if present.
    public func definition(for id: ItemDefinitionID) -> ItemDefinition? {
        definitionsByID[id]
    }

    /// Produces interaction candidates for a placed item.
    ///
    /// Offers contain advertised benefits but do not imply that the
    /// interaction is currently eligible or reachable.
    public func interactionOffers(for item: PlacedItem) throws -> [InteractionOffer] {
        guard let definition = definition(for: item.definitionID) else {
            throw ItemDefinitionCatalogError.missingDefinition(item.definitionID)
        }

        return definition.interactions
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map {
                InteractionOffer(
                    itemInstanceID: item.id,
                    itemDefinitionID: definition.id,
                    interaction: $0,
                )
            }
    }

    /// All definitions sorted by ID. Accessing this property is O(n log n).
    public var definitions: [ItemDefinition] {
        definitionsByID.values.sorted { $0.id.rawValue < $1.id.rawValue }
    }
}

/// An item decoded from lot or content JSON, with raw motive values.
struct Item: Broadcasting, Codable, Equatable {
    let identity: ItemIdentity
    let signals: [MotiveSignal]

    private enum CodingKeys: String, CodingKey {
        case name
        case itemType = "item"
        case motives
        case blocking
    }

    init(identity: ItemIdentity, signals: [MotiveSignal]) {
        self.identity = identity
        self.signals = signals
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identity = try ItemIdentity(
            name: container.decode(String.self, forKey: .name),
            itemTypes: ItemModifier.decodedSet(from: container, forKey: .itemType),
            isBlocking: container.decodeIfPresent(Bool.self, forKey: .blocking)
        )
        // Each entry names one motive and its raw value, divided by the scale.
        let rawMotives = try container.decode([[String: Double]].self, forKey: .motives)
        signals = try rawMotives.map { entry in
            guard entry.count == 1, let (name, rawValue) = entry.first else {
                throw DecodingError.dataCorruptedError(
                    forKey: .motives,
                    in: container,
                    debugDescription: "Each motive entry must name exactly one motive"
                )
            }
            guard let motiveType = MotiveType(rawValue: name) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .motives,
                    in: container,
                    debugDescription: "Unknown motive '\(name)'"
                )
            }
            return MotiveSignal(motiveType: motiveType, strengthPerSecond: rawValue / motiveStrengthScale)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identity.name, forKey: .name)
        if identity.itemTypes.count == 1, let onlyType = identity.itemTypes.first {
            try container.encode(onlyType, forKey: .itemType)
        } else {
            try container.encode(identity.itemTypes.sorted { $0.rawValue < $1.rawValue }, forKey: .itemType)
        }
        try container.encode(identity.isBlocking, forKey: .blocking)
        let rawMotives = signals.map {
            [$0.motiveType.rawValue: $0.strengthPerSecond * motiveStrengthScale]
        }
        try container.encode(rawMotives, forKey: .motives)
    }
}
