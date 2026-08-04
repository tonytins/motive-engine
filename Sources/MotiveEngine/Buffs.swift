import Foundation

protocol Buff: Sendable {
    func apply(in context: BuffContext) async -> [MotiveSignal]
}

struct BuffContext {
    let recipentName: String
    let broadcaster: Broadcasting
    let elepsedSeconds: Double
}

///  Ambient items (de)buff a sim just by existing
///  Some items are a hybrid. For example, can be a ambient and recreation item.
struct AmbientBuff: Buff {
    func apply(in context: BuffContext) async -> [MotiveSignal] {
        context.broadcaster.signals
    }
}

enum BuffRegistry {
    static func buffs(for broadcaster: Broadcasting) -> [Buff] {
        var boundBuffs: [Buff] = []
        if broadcaster.isAmbient {
            boundBuffs.append(AmbientBuff())
        }

        return boundBuffs
    }
}
