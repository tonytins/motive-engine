import Foundation

enum PersonalityTrait: String, Codable, CaseIterable, Hashable {
    case absentMinded = "Absent-minded"
    case artistic = "Artistic"
    case ambitious = "Ambitious"
    case avantGarde = "Avant garde"
    case bookworm = "Bookworm"
    case geek = "Geek"
    case eccentric = "Eccentric"
    case creative = "Creative"
    case hotHeaded = "Hot-headed"
    case paranoid = "Paranoid"
    case plantLover = "Plant Lover"
    case proper = "Proper"
    case muscLover = "Music Lover"
    case artLover = "Art Lover"
    case competitive = "Competitive"
    case lazy = "Lazy"
    case active = "Active"
    case goofball = "Goofball"
    case romatic = "Romantic"
    case erratic = "Erratic"
    case selfAssured = "Self-Assured"
    case unflirty = "Unflirty"
    case flirty = "Flirty"
}

struct WantOrFear: Codable, Hashable {
    let name: String
    let traits: [PersonalityTrait]
}

private struct WantsFearsPayload: Codable {
    enum CodingKeys: String, CodingKey {
        case wants = "want"
        case fears = "fear"
    }

    let wants: [String: [PersonalityTrait]]
    let fears: [String: [PersonalityTrait]]
}

struct WantFearCatalog {
    let wants: [WantOrFear]
    let fears: [WantOrFear]

    init(jsonData: Data) throws {
        let payload = try JSONDecoder().decode(WantsFearsPayload.self, from: jsonData)

        wants = payload.wants.map {
            WantOrFear(name: $0.key, traits: $0.value)
        }
        fears = payload.fears.map {
            WantOrFear(name: $0.key, traits: $0.value)
        }
    }

    init(wants: [WantOrFear], fears: [WantOrFear]) {
        self.wants = wants
        self.fears = fears
    }
}

struct FullfilledMotive {
    static let miniumValue: Double = 0.0
    static let maximumValue: Double = 100.0

    private(set) var value: Double

    init(startingValue: Double = maximumValue) {
        value = startingValue.clamped(to: Self.miniumValue ... Self.maximumValue)
    }

    mutating func decay(by amount: Double) {
        value = (value - amount).clamped(to: Self.miniumValue ... Self.maximumValue)
    }

    mutating func boost(by amount: Double) {
        value = (value + amount).clamped(to: Self.miniumValue ... Self.maximumValue)
    }
}

func matchScore(of item: WantOrFear, against personalityTraits: Set<PersonalityTrait>) -> Int {
    item.traits.count(where: {
        personalityTraits.contains($0)
    })
}

func rollWantsOrFears<Generator: RandomNumberGenerator>(
    from pool: [WantOrFear],
    matching personalityTraits: Set<PersonalityTrait>,
    count: Int,
    using randomNumberGenerator: inout Generator,
) -> [WantOrFear] {
    let shuffledPool = pool.shuffled(using: &randomNumberGenerator)
    let rankedPool = shuffledPool.enumerated().sorted {
        lhs, rhs in
        let lhsScore = matchScore(of: lhs.element, against: personalityTraits)
        let rhsScore = matchScore(of: rhs.element, against: personalityTraits)
        return lhsScore == rhsScore ? lhs.offset < rhs.offset : lhsScore > rhsScore
    }
    return rankedPool.prefix(max(0, count)).map(\.element)
}
