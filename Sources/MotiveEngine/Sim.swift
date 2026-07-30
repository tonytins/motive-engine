
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
    case sleep
    case fullfillWant(WantOrFear)
    case fullfillFear(WantOrFear)
}

struct SimStateMachine: Equatable, Sendable {
    // private(set) var activeFulfillments: [ActiveFulfillment]
    // private(set) var commandQueue: [PlayerCommand]
    let urgencyThreshold: Double
    let satisfiedThreshold: Double
    let maxConcurrentActivities: Int
    let maxQueuedCommands: Int
    let hasFreeWill: Bool
    let freeWillMotivePreference: [MotiveType]
}

enum SimPosture: String, Equatable, Sendable {
    case sitting
    case standing
}
