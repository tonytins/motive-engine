import Foundation

enum MotiveType: String, CaseIterable, Hashable, Codable {
    case hunger
    case energy
    case hygiene
    case bladder
    case social
    case fun
}

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

struct MotiveSignal: Equatable {
    let motiveType: MotiveType
    let strengthPerSecond: Double
}

struct MotiveDecayRates {
    private let ratesPerSecond: [MotiveType: Double]

    init(ratesPerSecond: [MotiveType: Double]) {
        self.ratesPerSecond = ratesPerSecond
    }
}

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

protocol Broadcasting: Sendable {
    var identity: ItemIdentity { get }
    var signals: [MotiveSignal] { get }
}

extension Broadcasting {
    var name: String { identity.name }
    var itemType: ItemType { identity.itemType }
    var isBlocking: Bool { identity.isBlocking }
    
    var isAmbient: Bool { identity.itemType == .ambient }
    
    var buffSignals: [MotiveSignal] {
        isAmbient ? signals : []
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
