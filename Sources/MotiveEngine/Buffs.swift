import Foundation

protocol Buff: Sendable {
    func apply(in context: BuffContext) async -> [MotiveSignal]
}

struct BuffContext: Sendable {
    let recipentName: String
    let broadcaster: Broadcasting
    let elepsedSeconds: Double
}

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
