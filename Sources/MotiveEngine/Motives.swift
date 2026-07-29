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
