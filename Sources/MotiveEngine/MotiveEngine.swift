import Foundation

enum Needs: String, CaseIterable, Hashable, Codable {
    case hunger
    case energy
    case hygiene
    case bladder
    case socializing
    case fun
}

enum Items: String, CaseIterable, Hashable, Codable {
    case fridge
    case bed
    case shower
    case toilet
    case phone
    case television
}

struct MotiveSignal: Codable, Equatable {
    let needs: Needs
    let strengthPerSecond: Double
}

protocol Broadcasting {
    var name: String { get }
    var items: Items { get }
    var signals: [MotiveSignal] { get }
}

protocol Motivated {
    var name: String { get }
    var needLevels: [Needs: Double] { get set }
    var decayRatesPerSeconds: [Needs: Double] { get }
}

extension Motivated {
    var lowestMotive: (needs: Needs, level: Double)? {
        guard let entry = needLevels.min(by: { $0.value < $1.value }) else { return nil }
        return (entry.key, entry.value)
    }

    mutating func decayMotives(overSeconds elapsedSeconds: Double) {
        needLevels = decayedMotiveLevels(
            from: needLevels,
            decayRatesPerSecond: decayRatesPerSeconds,
            overSeconds: elapsedSeconds,
        )
    }

    mutating func fullfilledNeeds(broadcastingFrom _: Broadcasting,
                                  overSeconds _: Double)
    {
        // needLevels =
    }
}
