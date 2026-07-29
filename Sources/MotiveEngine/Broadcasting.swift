import Foundation

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
