
let motiveStrengthScale = 25.0

enum ItemFunction: String, CaseIterable, Hashable, Codable {
    case comfort
    case plumbing
    case appliance
    case recreation
    case activity
    case lighting
    case decoration
    case sim
}

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

    var motivesFullfilledDirectly: Bool {
        self != .skill
    }

    var grantsSittingPosture: Bool {
        switch self {
        case .chair, .toilet:
            true
        default:
            false
        }
    }

    func delegatesTo(posture: SimPosture) -> Set<ItemModifier> {
        switch self {
        case .chair:
            [.recreation, .sim]
        case .recreation, .appliance:
            posture == .standing ? [.sim] : []
        default:
            []
        }
    }
}

extension ItemModifier {
    static func decodedSet<Key: CodingKey>(from container: KeyedDecodingContainer<Key>, forKey key: Key) throws -> Set<ItemModifier> {
        if let multiple = try? container.decode([ItemModifier].self, forKey: key) {
            guard !multiple.isEmpty else {
                throw DecodingError
                    .dataCorruptedError(
                        forKey: key,
                        in: container,
                        debugDescription: "Item must contain name of at least one type",
                    )
            }
            return Set(multiple)
        }

        return try [container.decode(ItemModifier.self, forKey: key)]
    }
}

public struct ItemIdentity: Equatable, Sendable {
    public let name: String
    public let itemTypes: Set<ItemModifier>
    public let isBlocking: Bool

    public init(name: String,
                itemTypes: some Sequence<ItemModifier>,
                isBlocking: Bool? = nil)
    {
        let set = Set(itemTypes)
        self.name = name
        self.itemTypes = set
        self.isBlocking = isBlocking ?? set.isBlockingByDefualt
    }

    public init(name: String, itemTypes: ItemModifier) {
        self.init(name: name, itemTypes: [itemTypes])
    }
}

/// A stable identifier for reusable item content.
public struct ItemDefinitionID: Codable, Hashable, Sendable {
    /// The content-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty, content-defined string.
    ///
    /// - Returns: `nil` when `rawValue` is empty.
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
                debugDescription: "Item definition ID must not be empty",
            )
        }
        self.rawValue = rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A stable identifier for one placed item instance.
public struct ItemInstanceID: Codable, Hashable, Sendable {
    /// The game-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty, game-defined string.
    ///
    /// - Returns: `nil` when `rawValue` is empty.
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
                debugDescription: "Item instance ID must not be empty",
            )
        }
        self.rawValue = rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A stable identifier for an interaction within item content.
public struct InteractionDefinitionID: Codable, Hashable, Sendable {
    /// The content-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty, content-defined string.
    ///
    /// - Returns: `nil` when `rawValue` is empty.
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
                debugDescription: "Interaction definition ID must not be empty",
            )
        }
        self.rawValue = rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
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

    /// Preconditions declared by the interaction.
    public let requirements: InteractionRequirements

    /// Creates interaction content with explicit advertised and applied values.
    ///
    /// - Throws: `InteractionDefinitionError` when the name is empty or a
    ///   strength is not finite.
    public init(
        id: InteractionDefinitionID,
        name: String,
        advertisedBenefits: [MotiveBenefit],
        motiveEffects: [MotiveSignal],
        requirements: InteractionRequirements = InteractionRequirements()
    ) throws {
        guard !name.isEmpty else {
            throw InteractionDefinitionError.emptyName
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
        self.requirements = requirements
    }
}

/// An error encountered while creating an interaction definition.
public enum InteractionDefinitionError: Error, Equatable, Sendable {
    /// The interaction name is empty.
    case emptyName

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

    /// Preconditions declared by the interaction.
    public let requirements: InteractionRequirements

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
        requirements = interaction.requirements
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

    /// Creates reusable item content with an explicit stable identifier.
    public init(
        id: ItemDefinitionID,
        identity: ItemIdentity,
        signals: [MotiveSignal],
        interactions: [InteractionDefinition] = []
    ) {
        self.id = id
        self.identity = identity
        self.signals = signals
        self.interactions = interactions
    }
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

struct Item: Broadcasting, Codable, Equatable {
    let identity: ItemIdentity
    let signals: [MotiveSignal]

    init(identity: ItemIdentity, signals: [MotiveSignal]) {
        self.identity = identity
        self.signals = signals
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case itemType = "item"
        case motives
        case blocking
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let itemTypes = try ItemModifier.decodedSet(
            from: container,
            forKey: .itemType,
        )

        if let explicitIsBlocking = try container.decodeIfPresent(
            Bool.self,
            forKey: .blocking,
        ) {
            identity = ItemIdentity(
                name: name,
                itemTypes: itemTypes,
                isBlocking: explicitIsBlocking,
            )
        } else {
            identity = ItemIdentity(
                name: name,
                itemTypes: itemTypes,
            )
        }

        let rawMotives = try container.decode([[String: Double]].self, forKey: .motives)

        signals = Item.signals(fromRawMotives: rawMotives)
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
            signal in
            [signal.motiveType.rawValue: signal.strengthPerSecond * motiveStrengthScale]
        }

        try container.encode(rawMotives, forKey: .motives)
    }
}

extension Item {
    static func signals(fromRawMotives rawMotives: [[String: Double]]) -> [MotiveSignal] {
        rawMotives.flatMap {
            motivepair -> [MotiveSignal] in
            motivepair.compactMap {
                key, needValue in
                guard let motiveType = MotiveType(rawValue: key) else { return nil }
                return MotiveSignal(
                    motiveType: motiveType,
                    strengthPerSecond: needValue
                        / motiveStrengthScale,
                )
            }
        }
    }
}
