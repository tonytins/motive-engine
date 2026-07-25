struct TickReport: Sendable {
    let simName: String
    let state: SimState
    let activeWants: [WantOrFear]
    let activeFears: [WantOrFear]
    let motiveValue: Double
}
