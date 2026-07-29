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
    var signals: [MotiveType] { get }
}

extension Broadcasting {
    var name: String { identity.name }
    var itemType: ItemType { identity.itemType }
    var isBlocking: Bool { identity.isBlocking }
    
    var isAmbient: Bool { identity.itemType == .ambient }
    
    var buffSignals: [MotiveType] {
        isAmbient ? signals : []
    }
}
