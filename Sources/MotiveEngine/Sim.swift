
enum IdleAction: Equatable {
    case fullfillWant(WantOrFear)
    case fullfillFear(WantOrFear)
    case remainIdle
}

protocol DecisionMaker: Sendable {
    func decide(wants: [WantOrFear], fears: [WantOrFear]) -> DecisionMaker
}

enum SimState: Equatable {
    case waking
    case idle
    case fullfillWant(WantOrFear)
    case fullfillFear(WantOrFear)
}

actor Sim {
    let name: String
    let personalityTraits: Set<PersonalityTrait>

    let mmotiveDecayPerTick: Double
    let motiveBoostPerWant: Double

    init(
        name: String,
        personalityTraits: Set<PersonalityTrait>,
        mmotiveDecayPerTick: Double = 3,
        motiveBoostPerWant: Double = 15,
    ) {
        self.name = name
        self.personalityTraits = personalityTraits
        self.mmotiveDecayPerTick = mmotiveDecayPerTick
        self.motiveBoostPerWant = motiveBoostPerWant
    }
}

enum SimPosture: String, Equatable, Sendable {
    case sitting
    case standing
}

extension ItemType {
    func delegatesTo(posture: SimPosture) -> Set<ItemType> {
        switch self {
        case .chair:
            return [.recreation, .sim]
        case .recreation, .fridge:
            return posture == .standing ? [.sim]: []
        default:
            return []
        }
    }
    
    var grantsSittingPosture: Bool {
        switch self {
        case .chair, .toilet:
            return true
        default:
            return false
        }
    }
}
