import Foundation

enum Needs: String, Codable {
    case hunger
    case energy
    case hygiene
    case bladder
    case socializing
    case fun
}

enum Items: String, Codable {
    case fridge
    case bed
    case shower
    case toilet
    case phone
    case television
}

struct ItemTracker: Codable {
    let needs: Needs
    let type: Items
    let strength: Double

    func needSignal() -> Double {
        strength
    }
}

struct Mood {
    let type: Needs
    var level: Double

    mutating func decrease(by amount: Double) {
        level = max(0, level - amount)
    }

    mutating func increase(by amount: Double) {
        level = min(100, level + amount)
    }

    var isCritical: Bool {
        level < 25
    }
}

struct Sim {
    var mood: [Mood]
    var currentNeed: Needs?
    var itemTracker: [ItemTracker]

    init(with tracker: [ItemTracker]) {
        itemTracker = tracker
        mood = [
            Mood(type: .hunger, level: Double.random(in: 50 ... 70)),
            Mood(type: .energy, level: Double.random(in: 50 ... 70)),
            Mood(type: .hygiene, level: Double.random(in: 50 ... 70)),
            Mood(type: .bladder, level: Double.random(in: 50 ... 70)),
            Mood(type: .socializing, level: Double.random(in: 50 ... 70)),
            Mood(type: .fun, level: Double.random(in: 50 ... 70)),
        ]
    }

    mutating func deteremineMood() {
        let mostCriticalNeed = mood.min(by: { $0.level < $1.level })
        currentNeed = mostCriticalNeed?.type
    }

    mutating func decayMood() {
        for index in mood.indices {
            mood[index].decrease(by: 4.5)
        }
    }

    mutating func fullfillNeed() {
        guard let focus = currentNeed else { return }

        let bestItem = itemTracker.filter { $0.needs == focus }.max { $0.strength < $1.strength }

        if let item = bestItem {
            if let moodIndex = mood.firstIndex(where: { $0.type == focus }) {
                mood[moodIndex].level = item.needSignal()
            }
        }
    }
}
