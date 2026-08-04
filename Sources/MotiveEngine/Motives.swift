import Foundation

enum MotiveType: String, CaseIterable, Hashable, Codable {
    case hunger
    case energy
    case hygiene
    case bladder
    case social
    case fun
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

struct MotiveLevels: Equatable {
    private var levels: [MotiveType: Double]

    init(levels: [MotiveType: Double]) {
        self.levels = levels
    }

    var lowest: (motiveType: MotiveType, level: Double)? {
        guard let entry = levels.min(by: { $0.value < $1.value }) else { return nil }

        return (entry.key, entry.value)
    }
}

protocol Motivated: Sendable {
    var name: String { get }
    var decayRates: MotiveDecayRates { get }
    func currentMotiveLevels() async -> MotiveLevels
    func decayMotives(overSeconds elapsedSeconds: Double) async
    func fulfillMotives(broadcastFrom broadcaster: Broadcasting, overSeconds elapsedSeconds: Double) async
}

extension Motivated {
    func lowestMotive() async -> (motiveType: MotiveType, level: Double)? {
        await currentMotiveLevels().lowest
    }
}
