import Foundation
import MotiveEngine

/// Runs Bob and Betty Newbie through a short simulation on the lot described
/// by `lot.json`, printing the events and motive state as time advances.
///
/// Pass a path as the first argument to load a different lot file.
///
/// Ambient items such as the Stereo apply a passive buff to nearby Sims.
/// Fields the engine does not simulate yet, such as `relationship`, are ignored.
@main
private enum NewbieHouse {
    private static let stepSeconds = 5.0
    private static let stepCount = 36
    private static let summaryInterval = 6
    private static let ambientRadius = 2

    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("NewbieHouse failed: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run() throws {
        let lotFile = try LotFile.load(from: lotURL())
        let world = try NewbieWorld(lotFile: lotFile)
        var session = try SimulationSession(
            state: world.state,
            itemCatalog: world.catalog,
            motiveDecayRates: decayRates(),
            buffRules: buffRules()
        )

        print("Newbie house: \(lotFile.width)x\(lotFile.height) lot, \(world.catalog.definitions.count) items")
        printMap(world: world, snapshot: SimulationSnapshot(state: session.state))
        printMotives(of: SimulationSnapshot(state: session.state), names: world.simNames, at: 0)

        // Betty heads straight for the shower at the player's request.
        // Bob is left to his own free will.
        var pendingCommands: [SimulationCommand] = []
        if let betty = world.simID(named: "Betty"), let shower = world.itemID(named: "Shower") {
            pendingCommands.append(
                .startInteraction(
                    simID: betty,
                    itemInstanceID: shower,
                    interactionDefinitionID: world.useInteractionID
                )
            )
        }

        for stepIndex in 1 ... stepCount {
            let time = Double(stepIndex) * stepSeconds
            let result = try session.step(bySeconds: stepSeconds, commands: pendingCommands)
            pendingCommands = []

            for event in result.events {
                guard let line = describe(event, world: world) else { continue }
                print("[t=\(format(time))s] \(line)")
            }

            if stepIndex.isMultiple(of: summaryInterval) || stepIndex == stepCount {
                printMap(world: world, snapshot: result.snapshot)
                printMotives(of: result.snapshot, names: world.simNames, at: time)
            }
        }
    }

    private static func lotURL() throws -> URL {
        let arguments = CommandLine.arguments
        if arguments.count > 1 {
            return URL(fileURLWithPath: arguments[1])
        }
        guard let url = Bundle.module.url(forResource: "lot", withExtension: "json") else {
            throw NewbieHouseError.missingLotResource
        }
        return url
    }

    private static func buffRules() throws -> BuffRuleSet {
        guard let ambientID = BuffID("ambient") else {
            throw NewbieHouseError.invalidIdentifier("ambient")
        }
        return try BuffRuleSet(rules: [AmbientBuffRule(id: ambientID, radius: ambientRadius)])
    }

    private static func decayRates() throws -> MotiveDecayRates {
        try MotiveDecayRates(ratesPerSecond: [
            .hunger: 0.30,
            .energy: 0.15,
            .hygiene: 0.20,
            .bladder: 0.35,
            .social: 0.10,
            .fun: 0.25,
        ])
    }

    // MARK: - Output

    private static func describe(_ event: SimulationEvent, world: NewbieWorld) -> String? {
        switch event {
        case .motivesChanged:
            // Motives change every step; they are summarized periodically instead.
            return nil
        case let .buffsApplied(simID, effects):
            let motives = Set(effects.flatMap(\.signals).map(\.motiveType.rawValue)).sorted()
            return "\(world.displayName(for: simID)) feels nearby ambience (\(motives.joined(separator: ", ")))"
        case let .actionChanged(simID, action):
            let who = world.displayName(for: simID)
            let item = world.itemName(for: action.offer.itemInstanceID)
            switch action.status {
            case .running where action.elapsedSeconds == 0:
                let why = action.initiator == .playerCommand ? "player command" : "free will"
                return "\(who) heads for the \(item) (\(why))"
            case .running:
                return nil
            case .completed:
                return "\(who) is done with the \(item)"
            case let .interrupted(reason):
                return "\(who) stopped using the \(item): \(reason)"
            case let .failed(reason):
                return "\(who) could not use the \(item): \(reason)"
            }
        case let .positionChanged(simID, from, to):
            return "\(world.displayName(for: simID)) walks (\(from.x),\(from.y)) -> (\(to.x),\(to.y))"
        case let .currentLotChanged(simID, _, to):
            return "\(world.displayName(for: simID)) moved to lot \(to?.rawValue ?? "none")"
        }
    }

    private static func printMap(world: NewbieWorld, snapshot: SimulationSnapshot) {
        guard let lot = snapshot.lots.first else { return }
        var rows = Array(
            repeating: Array(repeating: Character("."), count: lot.bounds.width),
            count: lot.bounds.height
        )
        for item in lot.placedItems {
            rows[item.position.y][item.position.x] = world.mapSymbol(for: item.id)
        }
        for (index, sim) in snapshot.sims.enumerated() {
            guard let position = sim.position else { continue }
            rows[position.y][position.x] = Character(String(index + 1))
        }
        print("")
        for row in rows {
            print("  " + String(row))
        }
        print("  " + world.legend(for: snapshot))
    }

    private static func printMotives(of snapshot: SimulationSnapshot, names: [SimID: String], at time: Double) {
        print("")
        print("t=\(format(time))s " + MotiveType.allCases.map { pad($0.rawValue, 8) }.joined())
        for sim in snapshot.sims {
            let levels = MotiveType.allCases.map { pad(format(sim.motives.level(for: $0)), 8) }
            let activity = sim.activeAction.map { " -> \($0.offer.name)" } ?? " (idle)"
            print(pad(names[sim.id] ?? sim.id.rawValue, 13) + levels.joined() + activity)
        }
        print("")
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.0f", value)
    }
}

// MARK: - Lot file

/// The subset of `lot.json` the example understands.
private struct LotFile: Decodable {
    struct ItemEntry: Decodable {
        let name: String
        let item: String
        let modifiers: [String]?
        let motives: [[String: Double]]
        let x: Int
        let y: Int
    }

    struct SimEntry: Decodable {
        let name: String
        let x: Int
        let y: Int
    }

    let width: Int
    let height: Int
    let items: [ItemEntry]
    let sims: [SimEntry]

    static func load(from url: URL) throws -> LotFile {
        try JSONDecoder().decode(LotFile.self, from: Data(contentsOf: url))
    }
}

// MARK: - World construction

/// Converts a lot file into engine definitions, placements, and Sim state.
private struct NewbieWorld {
    static let familyName = "Newbie"

    /// Lot motive values use the same per-second scale as the engine's item data.
    private static let motiveStrengthScale = 25.0
    private static let interactionSeconds = 20.0

    let state: SimulationState
    let useInteractionID: InteractionDefinitionID
    let catalog: ItemDefinitionCatalog
    let simNames: [SimID: String]
    private let itemIDsByName: [String: ItemInstanceID]
    private let simIDsByName: [String: SimID]
    private let symbolsByItemID: [ItemInstanceID: Character]

    init(lotFile: LotFile) throws {
        guard let lotID = LotID("newbie-lot"),
              let householdID = HouseholdID("newbie-household"),
              let useInteractionID = InteractionDefinitionID("use")
        else {
            throw NewbieHouseError.invalidIdentifier("newbie")
        }

        var definitions: [ItemDefinition] = []
        var placedItems: [PlacedItem] = []
        var itemIDsByName: [String: ItemInstanceID] = [:]
        var symbolsByItemID: [ItemInstanceID: Character] = [:]

        for entry in lotFile.items {
            let slug = Self.slug(entry.name)
            guard let definitionID = ItemDefinitionID(slug), let instanceID = ItemInstanceID(slug) else {
                throw NewbieHouseError.invalidIdentifier(entry.name)
            }

            // `item` values such as "comfort" or "plumbing" are item functions the
            // public API does not model yet; only recognized modifiers are kept.
            let modifiers = ([entry.item] + (entry.modifiers ?? [])).compactMap(ItemModifier.init(rawValue:))
            let signals = entry.motives.flatMap { pair in
                pair.sorted { $0.key < $1.key }.compactMap { key, value -> MotiveSignal? in
                    guard let motiveType = MotiveType(rawValue: key) else { return nil }
                    return MotiveSignal(motiveType: motiveType, strengthPerSecond: value / Self.motiveStrengthScale)
                }
            }

            // Ambient items work passively through the ambient buff rather than
            // offering an interaction.
            let interactions: [InteractionDefinition] = modifiers.contains(.ambient) ? [] : [
                try InteractionDefinition(
                    id: useInteractionID,
                    name: "Use \(entry.name)",
                    advertisedBenefits: signals.map {
                        MotiveBenefit(motiveType: $0.motiveType, expectedStrengthPerSecond: $0.strengthPerSecond)
                    },
                    motiveEffects: signals,
                    durationSeconds: Self.interactionSeconds
                ),
            ]

            definitions.append(try ItemDefinition(
                id: definitionID,
                identity: ItemIdentity(name: entry.name, itemTypes: modifiers),
                signals: signals,
                interactions: interactions
            ))
            placedItems.append(PlacedItem(
                id: instanceID,
                definitionID: definitionID,
                position: GridPosition(x: entry.x, y: entry.y)
            ))
            itemIDsByName[entry.name] = instanceID
            let usedSymbols = Set(symbolsByItemID.values)
            symbolsByItemID[instanceID] = entry.name.lowercased().first {
                $0.isLetter && !usedSymbols.contains($0)
            } ?? "#"
        }

        var sims: [SimStateData] = []
        var simNames: [SimID: String] = [:]
        var simIDsByName: [String: SimID] = [:]
        for entry in lotFile.sims {
            guard let simID = SimID(Self.slug(entry.name)) else {
                throw NewbieHouseError.invalidIdentifier(entry.name)
            }
            sims.append(SimStateData(
                id: simID,
                motives: try Self.startingMotives(for: entry.name),
                posture: .standing,
                currentLotID: lotID,
                position: GridPosition(x: entry.x, y: entry.y)
            ))
            simNames[simID] = "\(entry.name) \(Self.familyName)"
            simIDsByName[entry.name] = simID
        }

        self.useInteractionID = useInteractionID
        catalog = try ItemDefinitionCatalog(definitions: definitions)
        state = try SimulationState(
            sims: sims,
            households: [HouseholdState(id: householdID, memberIDs: sims.map(\.id))],
            lots: [LotState(
                id: lotID,
                bounds: GridSize(width: lotFile.width, height: lotFile.height),
                placedItems: placedItems
            )]
        )
        self.simNames = simNames
        self.itemIDsByName = itemIDsByName
        self.simIDsByName = simIDsByName
        self.symbolsByItemID = symbolsByItemID
    }

    func simID(named name: String) -> SimID? {
        simIDsByName[name]
    }

    func itemID(named name: String) -> ItemInstanceID? {
        itemIDsByName[name]
    }

    func displayName(for simID: SimID) -> String {
        simNames[simID] ?? simID.rawValue
    }

    func itemName(for itemID: ItemInstanceID) -> String {
        itemIDsByName.first { $0.value == itemID }?.key ?? itemID.rawValue
    }

    func mapSymbol(for itemID: ItemInstanceID) -> Character {
        symbolsByItemID[itemID] ?? "#"
    }

    /// Sims are numbered in snapshot order; items use a unique lowercase letter.
    func legend(for snapshot: SimulationSnapshot) -> String {
        let sims = snapshot.sims.enumerated().map { "\($0.offset + 1)=\(displayName(for: $0.element.id))" }
        let items = itemIDsByName.sorted { $0.key < $1.key }.map { "\(mapSymbol(for: $0.value))=\($0.key)" }
        return (sims + items).joined(separator: " ")
    }

    /// Bob starts the day hungry; Betty starts it in need of a shower.
    private static func startingMotives(for name: String) throws -> MotiveLevels {
        switch name {
        case "Bob":
            try MotiveLevels(levels: [
                .hunger: 25, .energy: 70, .hygiene: 80, .bladder: 60, .social: 55, .fun: 40,
            ])
        case "Betty":
            try MotiveLevels(levels: [
                .hunger: 65, .energy: 45, .hygiene: 20, .bladder: 70, .social: 60, .fun: 50,
            ])
        default:
            try MotiveLevels(levels: Dictionary(uniqueKeysWithValues: MotiveType.allCases.map { ($0, 75.0) }))
        }
    }

    private static func slug(_ name: String) -> String {
        name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: "-")
    }
}

private enum NewbieHouseError: Error {
    case missingLotResource
    case invalidIdentifier(String)
}
