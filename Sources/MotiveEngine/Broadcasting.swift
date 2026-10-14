
/// Something that offers motive signals, such as an item.
protocol Broadcasting: Sendable {
    var identity: ItemIdentity { get }
    var signals: [MotiveSignal] { get }
}

extension Broadcasting {
    var isAmbient: Bool {
        identity.itemTypes.contains(.ambient)
    }

    var isSelectable: Bool {
        !identity.itemTypes.subtracting([.ambient]).isEmpty
    }

    var buffSignals: [MotiveSignal] {
        isAmbient ? signals : []
    }
}

/// A change a Sim reports to its household.
enum BroadcastEvent: Equatable {
    case fallAsleep
    case wokeUp
}
