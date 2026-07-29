
enum ItemType: String, CaseIterable, Hashable, Codable {
    case fridge
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
        case .fridge, .bed, .shower, .toilet, .recreation, .chair, .skill:
            return true
        case .sim, .ambient:
                return false
        }
    }
    
    var motivesFullfilledDirectly: Bool {
        self != .skill
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
    
    init(name: String, itemTypes: Set<ItemType>, isBlocking: Bool) {
        self.name = name
        self.itemTypes = itemTypes
        self.isBlocking = isBlocking
    }
    
    init(name: String, itemTypes: ItemType, isBlocking: Bool) {
        self.init(name: name, itemTypes: [itemTypes], isBlocking: isBlocking)
    }
    
    init(name: String, itemTypes: ItemType) {
        self.init(
            name: name,
            itemTypes: [itemTypes],
            isBlocking: itemTypes.isBlockingByDefault
        )
    }
    
    init(name: String, itemTypes: Set<ItemType>) {
        self.init(
            name: name,
            itemTypes: itemTypes
        )
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
        let container = try encoder.container(keyedBy: CodingKeys.self)
        
        
    }
}

let motiveStrengthScale = 25.0

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

protocol Broadcasting: Sendable {
    var identity: ItemIdentity { get }
    var signals: [MotiveSignal] { get }
}

extension Broadcasting {
    var name: String { identity.name }
    var itemType: Set<ItemType> { identity.itemTypes }
    var isBlocking: Bool { identity.isBlocking }
    
    var isAmbient: Bool { identity.itemTypes == [.ambient] }
    
    var buffSignals: [MotiveSignal] {
        isAmbient ? signals : []
    }
}
