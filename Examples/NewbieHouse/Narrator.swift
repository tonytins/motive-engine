import Foundation
import MotiveEngine

/// Turns simulation events and snapshots into readable text.
struct Narrator {
    let labels: Labels

    /// A line describing an event, or `nil` for events too frequent to print.
    func describe(_ event: SimulationEvent) -> String? {
        switch event {
        case .motivesChanged:
            // Motives change every step; they are summarized periodically instead.
            return nil
        case let .buffsApplied(simID, effects):
            let motives = Set(effects.flatMap(\.signals).map(\.motiveType.rawValue)).sorted()
            return "\(labels.name(of: simID)) feels nearby ambience (\(motives.joined(separator: ", ")))"
        case let .timedBuffApplied(simID, buff):
            return "\(labels.name(of: simID)) gains \(buff.id.rawValue)"
        case let .timedBuffExpired(simID, buffID):
            return "\(labels.name(of: simID)) loses \(buffID.rawValue)"
        case let .actionChanged(simID, action):
            return describe(action, by: simID)
        case let .positionChanged(simID, from, to):
            return "\(labels.name(of: simID)) walks (\(from.x),\(from.y)) -> (\(to.x),\(to.y))"
        case let .currentLotChanged(simID, _, to):
            return "\(labels.name(of: simID)) moved to lot \(to?.rawValue ?? "none")"
        case let .interactionCoolingDown(interaction, failures, seconds):
            return "\(labels.name(of: interaction)) failed \(failures) time(s); free will waits \(Self.format(seconds))s"
        case let .scriptDisabled(interaction):
            return "\(labels.name(of: interaction)) script disabled; using its written effects"
        case let .interactionDisabled(interaction):
            return "\(labels.name(of: interaction)) disabled; it has no written effects to fall back on"
        case let .packDisabled(packID, .failingInteractions):
            return "content pack \(packID.rawValue) disabled: too many broken interactions"
        case let .packDisabled(packID, .dependencyDisabled(dependency)):
            return "content pack \(packID.rawValue) disabled: it needs \(dependency.rawValue)"
        case let .interactionEnabled(interaction):
            return "\(labels.name(of: interaction)) re-enabled"
        case let .packEnabled(packID):
            return "content pack \(packID.rawValue) re-enabled"
        }
    }

    /// Prints the lot as a grid: items by letter, Sims by number.
    func printMap(_ snapshot: SimulationSnapshot) {
        guard let lot = snapshot.lots.first else { return }
        var rows = Array(
            repeating: Array(repeating: Character("."), count: lot.bounds.width),
            count: lot.bounds.height
        )
        for item in lot.placedItems {
            rows[item.position.y][item.position.x] = labels.symbol(of: item.id)
        }
        for (index, sim) in snapshot.sims.enumerated() {
            guard let position = sim.position else { continue }
            rows[position.y][position.x] = Character(String(index + 1))
        }
        print("")
        for row in rows {
            print("  " + String(row))
        }
        print("  " + labels.legend(for: snapshot))
    }

    /// Prints every Sim's motive levels and current activity.
    func printMotives(_ snapshot: SimulationSnapshot, at time: Double) {
        print("")
        print("t=\(Self.format(time))s " + MotiveType.allCases.map { Self.pad($0.rawValue, 8) }.joined())
        for sim in snapshot.sims {
            let levels = MotiveType.allCases.map { Self.pad(Self.format(sim.motives.level(for: $0)), 8) }
            let activity = sim.activeAction.map { " -> \($0.offer.name)" } ?? " (idle)"
            print(Self.pad(labels.name(of: sim.id), 13) + levels.joined() + activity)
        }
        print("")
    }

    /// A whole number, for times and motive levels.
    static func format(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    private func describe(_ action: InteractionActionState, by simID: SimID) -> String? {
        let who = labels.name(of: simID)
        let item = labels.name(of: action.offer.itemInstanceID)
        switch action.status {
        case .running where action.elapsedSeconds == 0:
            let why = action.initiator == .playerCommand ? "player command" : "free will"
            return "\(who) heads for the \(item) to \(action.offer.name.lowercased()) (\(why))"
        case .running:
            return nil
        case .completed:
            return "\(who) is done with the \(item)"
        case let .interrupted(reason):
            return "\(who) stopped using the \(item): \(reason)"
        case let .failed(.scriptFailed(.runtime(error))):
            return "\(who) could not use the \(item): its script failed (\(error.message))"
        case let .failed(.scriptFailed(.invalidEffect(error))):
            return "\(who) could not use the \(item): its script reported an invalid effect (\(error))"
        case let .failed(reason):
            return "\(who) could not use the \(item): \(reason)"
        }
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }
}
