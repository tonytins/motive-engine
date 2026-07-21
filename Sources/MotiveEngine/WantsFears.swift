import Foundation

enum PersonalityTrait: String, Codable, CaseIterable, Hashable {
    case outgoing = "Outgoing"
    case ambitious = "Ambitious"
    case creative = "Creative"
    case imaginative = "Imaginative"
    case adventurous = "Adventurous"
    case curious = "Curious"
    case nurturing = "Nurturing"
    case familyOriented = "Family-Oriented"
    case competitive = "Competitive"
    case shy = "Shy"
    case insecure = "Insecure"
    case anxious = "Anxious"
    case riskAverse = "Risk-Averse"
    case social = "Social"
    case lonely = "Lonely"
    case avoidant = "Avoidant"
    case independent = "Independent"
    case nervous = "Nervous"
}

struct WantOrFear: Codable, Hashable {
    let name: String
    let traits: [PersonalityTrait]
}

private struct WantsFearsPayload: Codable {
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

    init(wants: [WantOrFear], fears _: [WantOrFear]) {
        self.wants = wants
        fears = wants
    }
}

// Unit testing logic

internal func MatchScore(of item: WantOrFear, against personalityTraits: Set<PersonalityTrait>) -> Int {
    item.traits.filter { personalityTraits.contains($0) }.count
}

internal func rollWantsOrFears(
    from pool: [WantOrFear],
    matching personalityTraits: Set<PersonalityTrait>,
    count: Int,
    using randomNumberGenerator: inout RandomNumberGenerator
) -> [WantOrFear] {
    let shuffledPool = pool.shuffled(using: &randomNumberGenerator)
    let rankedPool = shuffledPool.sorted {
        lhs, rhs in
        MatchScore(of: lhs, against: personalityTraits) >
        MatchScore(of: rhs,against: personalityTraits)
    }
    return Array(rankedPool.prefix(count))
}
