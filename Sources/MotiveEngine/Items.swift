
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

/// Reusable item content, separate from any placed item instance.
public struct ItemDefinition: Broadcasting, Equatable, Sendable {
    /// The stable identifier used by placed instances.
    public let id: ItemDefinitionID

    /// The name, item modifiers, and blocking behavior shared by instances.
    public let identity: ItemIdentity

    /// The motive signals offered by this item content.
    public let signals: [MotiveSignal]

    /// Creates reusable item content with an explicit stable identifier.
    public init(id: ItemDefinitionID, identity: ItemIdentity, signals: [MotiveSignal]) {
        self.id = id
        self.identity = identity
        self.signals = signals
    }
}

/// An error produced while building an item definition catalog.
public enum ItemDefinitionCatalogError: Error, Equatable, Sendable {
    /// Two definitions use the same identifier.
    case duplicateDefinitionID(ItemDefinitionID)
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
            definitionsByID[definition.id] = definition
        }
        self.definitionsByID = definitionsByID
    }

    /// Returns the definition with the specified ID, if present.
    public func definition(for id: ItemDefinitionID) -> ItemDefinition? {
        definitionsByID[id]
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
