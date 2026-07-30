
let motiveStrengthScale = 25.0

enum ItemType: String, CaseIterable, Hashable, Codable {
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
            return true
        case .sim, .ambient:
                return false
        }
    }
    
    var motivesFullfilledDirectly: Bool {
        self != .skill
    }
    
    var grantsSittingPosture: Bool {
        switch self {
        case .chair, .toilet:
            return true
        default:
            return false
        }
    }
    
    func delegatesTo(posture: SimPosture) -> Set<ItemType> {
        switch self {
        case .chair:
            return [.recreation, .sim]
        case .recreation, .appliance:
            return posture == .standing ? [.sim] : []
        default:
            return []
        }
    }
}

extension ItemType {
    static func decodedSet<Key: CodingKey>(from container: KeyedDecodingContainer<Key>, forKey key: Key) throws -> Set<ItemType> {
        if let multiple = try? container.decode([ItemType].self, forKey: key) {
            guard !multiple.isEmpty else {
                throw DecodingError
                    .dataCorruptedError(
                        forKey: key,
                        in: container,
                        debugDescription: "Item must contain name of at least one type"
                    )
            }
            return Set(multiple)
        }
        
        return [try container.decode(ItemType.self, forKey: key)]
    }
}

struct ItemIdentity: Equatable, Sendable {
    let name: String
    let itemTypes: Set<ItemType>
    let isBlocking: Bool
    
    init<S: Sequence>(name: String,
                      itemTypes: S,
                      isBlocking: Bool? = nil)
    where S.Element == ItemType {
        let set = Set(itemTypes)
        self.name = name
        self.itemTypes = set
        self.isBlocking = isBlocking ?? set.isBlockingByDefualt
        }
    
    init(name: String, itemTypes: ItemType) {
        self.init(name: name, itemTypes: [itemTypes])
    }
}

struct Item: Broadcasting, Codable, Equatable, Sendable {

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
        let itemTypes = try ItemType.decodedSet(
            from: container,
            forKey: .itemType
        )
    
        if let explicitIsBlocking = try container.decodeIfPresent(
            Bool.self,
            forKey: .blocking
        ) {
            identity = ItemIdentity(
                name: name,
                itemTypes: itemTypes,
                isBlocking: explicitIsBlocking
            )
        } else {
            identity = ItemIdentity(
                name: name,
                itemTypes: itemTypes
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
                 / motiveStrengthScale)
            }
        }
    }
    
}
