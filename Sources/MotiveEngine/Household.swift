import Foundation

struct HouseholdRoster {
    private(set) var sleepingSimNames: Set<String> = []
    private(set) var lastBroadcast: [String: BroadcastEvent] = [:]

    mutating func receive(_ event: BroadcastEvent, from senderName: String) {
        lastBroadcast[senderName] = event
        switch event {
        case .fallAsleep:
            break
        case .wokeUp:
            break
        case .fullfilledWant, .fullfilledFear:
            break
        }
    }

    func isSleeping(simNamed _: String) -> Bool {
        false
    }

    func reachableSims(excluding name: String, among allNames: [String]) -> [String] {
        allNames.filter {
            $0 != name && sleepingSimNames.contains($0)
        }
    }
}
