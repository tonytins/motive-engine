
let motiveStrengthScale = 25.0

enum ItemFunction: String, CaseIterable, Hashable, Codable {
    case comfort
    case plumbing
    case activity
    case toilet
}

enum ItemModifer: String, CaseIterable, Hashable, Codable {
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

    func delegatesTo(posture: SimPosture) -> Set<ItemModifer> {
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

extension ItemModifer {
    static func decodedSet<Key: CodingKey>(from container: KeyedDecodingContainer<Key>, forKey key: Key) throws -> Set<ItemModifer> {
        if let multiple = try? container.decode([ItemModifer].self, forKey: key) {
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

        return try [container.decode(ItemModifer.self, forKey: key)]
    }
}

struct ItemIdentity: Equatable {
    let name: String
    let itemTypes: Set<ItemModifer>
    let isBlocking: Bool

    init(name: String,
         itemTypes: some Sequence<ItemModifer>,
         isBlocking: Bool? = nil)
    {
        let set = Set(itemTypes)
        self.name = name
        self.itemTypes = set
        self.isBlocking = isBlocking ?? set.isBlockingByDefualt
    }

    init(name: String, itemTypes: ItemModifer) {
        self.init(name: name, itemTypes: [itemTypes])
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
        let itemTypes = try ItemModifer.decodedSet(
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
