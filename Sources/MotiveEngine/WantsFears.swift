import Foundation

enum PersonalityTrait: String, Codable, CaseIterable, Hashable {
    case absentMinded = "Absent-minded"
    case artistic = "Artistic"
    case ambitious = "Ambitious"
    case avantGarde = "Avant garde"
    case bookworm = "Bookworm"
    case geek = "Geek"
    case eccentric = "Eccentric"
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

    init(wants: [WantOrFear], fears: [WantOrFear]) {
        self.wants = wants
        self.fears = fears
    }
}

func matchScore(of item: WantOrFear, against personalityTraits: Set<PersonalityTrait>) -> Int {
    item.traits.count(where: {
        personalityTraits.contains($0)
    })
}

func rollWantsOrFears(
    from pool: [WantOrFear],
    matching personalityTraits: Set<PersonalityTrait>,
    count: Int,
    using randomNumberGenerator: inout RandomNumberGenerator,
) -> [WantOrFear] {
    let shuffledPool = pool.shuffled(using: &randomNumberGenerator)
    let rankedPool = shuffledPool.sorted {
        lhs, rhs in matchScore(of: lhs, against: personalityTraits) > matchScore(
            of: rhs,
            against: personalityTraits,
        )
    }
    return Array(rankedPool.prefix(count))
}

enum SimState: Equatable {
    case waking
    case idle
    case fulfilledWant(WantOrFear)
    case fulfilledFear(WantOrFear)
}

enum IdleAction: Equatable {
    case fulfilledWant(WantOrFear)
    case fulfilledFear(WantOrFear)
    case remainIdle
}

func chooseIdleAction(
    wants: [WantOrFear],
    fears: [WantOrFear],
    using randomNumberGenerator: inout RandomNumberGenerator,
) -> IdleAction {
    guard !wants.isEmpty || !fears.isEmpty else { return .remainIdle }

    let shouldFavorFear = Bool.random(using: &randomNumberGenerator)
    guard shouldFavorFear else {
        guard let want = wants.randomElement(using: &randomNumberGenerator) else {
            guard let fear = fears.randomElement(using: &randomNumberGenerator) else { return .remainIdle }
            return .fulfilledFear(fear)
        }
        return .fulfilledWant(want)
    }

    guard let fear = fears.randomElement(using: &randomNumberGenerator) else {
        guard let want = wants.randomElement(using: &randomNumberGenerator) else { return .remainIdle }
        return .fulfilledWant(want)
    }
    return .fulfilledFear(fear)
}

func nextState(for action: IdleAction) -> SimState {
    switch action {
    case let .fulfilledWant(want):
        return .fulfilledWant(want)
    case let .fulfilledFear(fear):
        return .fulfilledFear(fear)
    case .remainIdle:
    default:
        return .idle
    }
}

actor Sim {
    let name: String
    let personalityTraits: Set<PersonalityTrait>

    private let catalog: WantFearCatalog
    private let activeWantCount: Int
    private let activeFearCount: Int
    private var randomNumberGenerator: RandomNumberGenerator

    private(set) var state: SimState = .waking
    private(set) var activeWants: [WantOrFear] = []
    private(set) var activeFears: [WantOrFear] = []

    init(
        name: String,
        personalityTraits: Set<PersonalityTrait>,
        catalog: WantFearCatalog,
        activeWantCount: Int = 3,
        activeFearCount: Int = 2,
        randomNumberGenerator: RandomNumberGenerator = SystemRandomNumberGenerator(),
    ) async {
        self.name = name
        self.personalityTraits = personalityTraits
        self.catalog = catalog
        self.activeWantCount = activeWantCount
        self.activeFearCount = activeFearCount
        self.randomNumberGenerator = randomNumberGenerator
    }

    func wakeUp() {
        state = .waking
    }

    private func reshuffleWantsAndFears() {
        activeWants = rollWantsOrFears(
            from: catalog.wants,
            matching: personalityTraits,
            count: activeFearCount,
            using: &randomNumberGenerator,
        )

        activeFears = rollWantsOrFears(
            from: catalog.fears,
            matching: personalityTraits,
            count: activeFearCount,
            using: &randomNumberGenerator,
        )
    }

    func step() {
        switch state {
        case .waking:
            state = .idle
        case .idle:
            let action = chooseIdleAction(
                wants: activeWants,
                fears: activeFears,
                using: &randomNumberGenerator,
            )
            state = nextState(for: action)
        case let .fulfilledWant(wantOrFear):
            reshuffleWantsAndFears()
            state = .idle
        case let .fulfilledFear(wantOrFear):
            reshuffleWantsAndFears()
            state = .idle
        }
    }
}
