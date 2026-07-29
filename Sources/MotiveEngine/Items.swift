
struct ItemIdentity: Equatable, Sendable {
    let name: String
    let itemType: ItemType
    let isBlocking: Bool
    
    init(name: String, itemType: ItemType, isBlocking: Bool) {
        self.name = name
        self.itemType = itemType
        self.isBlocking = isBlocking
    }
    
    init(name: String, itemType: ItemType) {
        self.name = name
        self.itemType = itemType
        self.isBlocking = itemType.isBlockingByDefault
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
        let itemType = try container.decode(ItemType.self, forKey: .itemType)
    
        if let explicitIsBlocking = try container.decodeIfPresent(
            Bool.self,
            forKey: .blocking
        ) {
            identity = ItemIdentity(
                name: name,
                itemType: itemType,
                isBlocking: explicitIsBlocking
            )
        } else {
            identity = ItemIdentity(
                name: name,
                itemType: itemType
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
