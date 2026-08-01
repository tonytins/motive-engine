
protocol Broadcasting: Sendable {
    var identity: ItemIdentity { get }
    var signals: [MotiveSignal] { get }
}

extension Broadcasting {
    var name: String { identity.name }
    var itemType: Set<ItemModifer> { identity.itemTypes }
    var isBlocking: Bool { identity.isBlocking }
    
    var isAmbient: Bool { identity.itemTypes == [.ambient] }
    
    var isSelectable: Bool {
        !identity.itemTypes.subtracting([.ambient]).isEmpty
    }
    
    var strongestMotiveType: MotiveType? {
        signals
            .max(
                by: { $0.strengthPerSecond < $1.strengthPerSecond
                })?.motiveType
    }
    
    var buffSignals: [MotiveSignal] {
        isAmbient ? signals : []
    }
}


enum BroadcastEvent {
    case fallAsleep
    case wokeUp
    case fullfilledWant(WantOrFear)
    case fullfilledFear(WantOrFear)

}
