import Foundation

struct HouseholdRoster {
    private(set) var sleepingSimNames: Set<String> = []
    private(set) var lastBroadcast: [String: BroadcastEvent] = [:]

    mutating func receive(_ event: BroadcastEvent, from senderName: String) {
        lastBroadcast[senderName] = event
        switch event {
        case .fallAsleep:
            sleepingSimNames.insert(senderName)
        case .wokeUp:
            sleepingSimNames.remove(senderName)
        }
    }

    func isSleeping(simNamed name: String) -> Bool {
        sleepingSimNames.contains(name)
    }

    func reachableSims(excluding name: String, among allNames: [String]) -> [String] {
        allNames.filter {
            $0 != name && !sleepingSimNames.contains($0)
        }
    }
}
