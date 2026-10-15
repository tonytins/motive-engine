import Foundation
import MotiveEngine

/// Runs Bob and Betty Newbie through a short simulation, printing events and
/// motive levels as time advances.
///
/// Items come from content packs in the bundled `Content` folder: the `base`
/// pack and the `newbie-extras` mod, which overrides the base television and
/// adds an aquarium. `lot.json` only places items and Sims.
///
/// Usage:
///
///     swift run NewbieHouse [--broken-mod] [--lot <file>] [<pack folder> ...]
///
/// - `--broken-mod` also loads `broken-gadgets`, whose scripts always fail, to
///   show cooldowns, fallbacks, and disabled content.
/// - `--lot` loads a different layout.
/// - Any other argument is a pack folder to load after the bundled packs.
@main
private enum NewbieHouse {
    private static let stepSeconds = 5.0
    private static let stepCount = 36
    private static let summaryInterval = 6
    private static let ambientRadius = 2

    static func main() {
        do {
            try run(options: Options(arguments: Array(CommandLine.arguments.dropFirst())))
        } catch {
            FileHandle.standardError.write(Data("NewbieHouse failed: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run(options: Options) throws {
        let content = try loadContent(options: options)
        let layout = try LotFile.load(from: options.lotURL ?? bundledURL("lot", extension: "json"))
        let world = try NewbieWorld(layout: layout, content: content)
        var session = try SimulationSession(
            state: world.state,
            content: content,
            motiveDecayRates: decayRates(),
            buffRules: buffRules(),
            scriptFailurePolicy: ScriptFailurePolicy(
                cooldownSeconds: 20,
                failuresBeforeDisabling: 2,
                disabledInteractionsBeforeDisablingPack: 3
            )
        )

        print("Newbie house: \(layout.width)x\(layout.height) lot, \(world.placedItemCount) items placed")
        printMap(world: world, snapshot: SimulationSnapshot(state: session.state))
        printMotives(of: SimulationSnapshot(state: session.state), world: world, at: 0)

        // Betty heads straight for the shower at the player's request.
        // Bob is left to his own free will.
        var pendingCommands: [SimulationCommand] = []
        if let betty = world.simID(named: "Betty"),
           let shower = ItemInstanceID("shower"),
           let takeShower = InteractionDefinitionID("shower")
        {
            pendingCommands.append(.startInteraction(
                simID: betty,
                itemInstanceID: shower,
                interactionDefinitionID: takeShower
            ))
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
                printMotives(of: result.snapshot, world: world, at: time)
            }
        }

        if !session.contentHealth.disabledPacks.isEmpty {
            let packs = session.contentHealth.disabledPacks.keys.map(\.rawValue).sorted()
            print("Disabled until re-enabled by the player: \(packs.joined(separator: ", "))")
        }
    }

    // MARK: - Content

    /// Loads the bundled packs and any extra pack folders, then composes them.
    private static func loadContent(options: Options) throws -> ContentComposition {
        let contentFolder = try bundledURL("Content", extension: nil)
        var folders = ["base", "newbie-extras"].map { contentFolder.appendingPathComponent($0) }
        if options.loadsBrokenMod {
            folders.append(contentFolder.appendingPathComponent("broken-gadgets"))
        }
        folders += options.extraPackFolders

        let packs = try folders.map { folder in
            do {
                return try ContentPack(loadingFrom: DirectoryContentSource(directory: folder))
            } catch {
                throw NewbieHouseError.packFailedToLoad(folder: folder.path, reason: String(describing: error))
            }
        }
        let composition = try ContentComposer.compose(packs)

        print("Content packs, in load order:")
        for pack in packs.sorted(by: { order(of: $0, in: composition) < order(of: $1, in: composition) }) {
            let manifest = pack.manifest
            let dependencies = manifest.dependencies.isEmpty
                ? ""
                : ", needs \(manifest.dependencies.map(\.rawValue).joined(separator: ", "))"
            let overrides = manifest.overrides.isEmpty
                ? ""
                : ", replaces \(manifest.overrides.map(\.rawValue).joined(separator: ", "))"
            print("  \(manifest.id.rawValue): \(manifest.name)\(dependencies)\(overrides)")
        }
        for conflict in composition.conflicts {
            let packs = conflict.packIDs.map(\.rawValue).joined(separator: ", ")
            print("  Conflict: \(packs) all replace \(conflict.definitionID.rawValue); the last one wins")
        }
        print("")
        return composition
    }

    private static func order(of pack: ContentPack, in composition: ContentComposition) -> Int {
        composition.loadOrder.firstIndex(of: pack.manifest.id) ?? Int.max
    }

    private static func bundledURL(_ name: String, extension fileExtension: String?) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension) else {
            throw NewbieHouseError.missingResource(name)
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
        case let .timedBuffApplied(simID, buff):
            return "\(world.displayName(for: simID)) gains \(buff.id.rawValue)"
        case let .timedBuffExpired(simID, buffID):
            return "\(world.displayName(for: simID)) loses \(buffID.rawValue)"
        case let .actionChanged(simID, action):
            let who = world.displayName(for: simID)
            let item = world.itemName(for: action.offer.itemInstanceID)
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
            case let .failed(.scriptFailed(failure)):
                return "\(who) could not use the \(item): its script failed (\(describe(failure)))"
            case let .failed(reason):
                return "\(who) could not use the \(item): \(reason)"
            }
        case let .positionChanged(simID, from, to):
            return "\(world.displayName(for: simID)) walks (\(from.x),\(from.y)) -> (\(to.x),\(to.y))"
        case let .interactionCoolingDown(interaction, failures, seconds):
            return "\(world.definitionName(interaction)) failed \(failures) time(s); free will waits \(format(seconds))s"
        case let .scriptDisabled(interaction):
            return "\(world.definitionName(interaction)) script disabled; using its written effects"
        case let .interactionDisabled(interaction):
            return "\(world.definitionName(interaction)) disabled; it has no written effects to fall back on"
        case let .packDisabled(packID, reason):
            switch reason {
            case .failingInteractions:
                return "content pack \(packID.rawValue) disabled: too many broken interactions"
            case let .dependencyDisabled(dependency):
                return "content pack \(packID.rawValue) disabled: it needs \(dependency.rawValue)"
            }
        case let .interactionEnabled(interaction):
            return "\(world.definitionName(interaction)) re-enabled"
        case let .packEnabled(packID):
            return "content pack \(packID.rawValue) re-enabled"
        case let .currentLotChanged(simID, _, to):
            return "\(world.displayName(for: simID)) moved to lot \(to?.rawValue ?? "none")"
        }
    }

    private static func describe(_ failure: InteractionScriptFailure) -> String {
        switch failure {
        case let .runtime(error):
            error.message
        case let .invalidEffect(error):
            "invalid effect: \(error)"
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

    private static func printMotives(of snapshot: SimulationSnapshot, world: NewbieWorld, at time: Double) {
        print("")
        print("t=\(format(time))s " + MotiveType.allCases.map { pad($0.rawValue, 8) }.joined())
        for sim in snapshot.sims {
            let levels = MotiveType.allCases.map { pad(format(sim.motives.level(for: $0)), 8) }
            let activity = sim.activeAction.map { " -> \($0.offer.name)" } ?? " (idle)"
            print(pad(world.displayName(for: sim.id), 13) + levels.joined() + activity)
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

// MARK: - Command line

private struct Options {
    var loadsBrokenMod = false
    var lotURL: URL?
    var extraPackFolders: [URL] = []

    init(arguments: [String]) throws {
        var remaining = arguments[...]
        while let argument = remaining.popFirst() {
            switch argument {
            case "--broken-mod":
                loadsBrokenMod = true
            case "--lot":
                guard let path = remaining.popFirst() else {
                    throw NewbieHouseError.missingValue("--lot")
                }
                lotURL = URL(fileURLWithPath: path)
            default:
                extraPackFolders.append(URL(fileURLWithPath: argument))
            }
        }
    }
}

// MARK: - Lot layout

/// `lot.json`: the lot's size, where items are placed, and the Sims.
///
/// Items are placed by their qualified definition ID, such as `base:fridge`.
/// Fields the engine does not simulate yet, such as `relationship`, are
/// ignored.
private struct LotFile: Decodable {
    struct ItemEntry: Decodable {
        let id: ItemInstanceID
        let definition: ItemDefinitionID
        let x: Int
        let y: Int
    }

    struct SimEntry: Decodable {
        let name: String
        let x: Int
        let y: Int
        let motives: [String: Double]
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

/// Builds the world from a lot layout and composed content.
private struct NewbieWorld {
    static let familyName = "Newbie"

    let state: SimulationState
    let placedItemCount: Int
    private let content: ContentComposition
    private let simNames: [SimID: String]
    private let simIDsByName: [String: SimID]
    private let itemNames: [ItemInstanceID: String]
    private let symbolsByItemID: [ItemInstanceID: Character]

    init(layout: LotFile, content: ContentComposition) throws {
        guard let lotID = LotID("newbie-lot"), let householdID = HouseholdID("newbie-household") else {
            throw NewbieHouseError.invalidIdentifier("newbie")
        }

        // A game would warn about items from packs that aren't installed; this
        // example lists them and leaves them off the lot.
        var placedItems: [PlacedItem] = []
        var skippedPacks: Set<String> = []
        var itemNames: [ItemInstanceID: String] = [:]
        var symbolsByItemID: [ItemInstanceID: Character] = [:]
        for entry in layout.items {
            guard let definition = content.catalog.definition(for: entry.definition) else {
                skippedPacks.insert(entry.definition.rawValue.split(separator: ":").first.map(String.init) ?? "?")
                continue
            }
            placedItems.append(PlacedItem(
                id: entry.id,
                definitionID: entry.definition,
                position: GridPosition(x: entry.x, y: entry.y)
            ))
            itemNames[entry.id] = definition.identity.name
            let usedSymbols = Set(symbolsByItemID.values)
            symbolsByItemID[entry.id] = definition.identity.name.lowercased().first {
                $0.isLetter && !usedSymbols.contains($0)
            } ?? "#"
        }
        if !skippedPacks.isEmpty {
            print("Skipped items from packs that aren't loaded: \(skippedPacks.sorted().joined(separator: ", "))\n")
        }

        var sims: [SimStateData] = []
        var simNames: [SimID: String] = [:]
        var simIDsByName: [String: SimID] = [:]
        for entry in layout.sims {
            guard let simID = SimID(entry.name.lowercased()) else {
                throw NewbieHouseError.invalidIdentifier(entry.name)
            }
            sims.append(SimStateData(
                id: simID,
                motives: try Self.motives(entry.motives, for: entry.name),
                posture: .standing,
                currentLotID: lotID,
                position: GridPosition(x: entry.x, y: entry.y)
            ))
            simNames[simID] = "\(entry.name) \(Self.familyName)"
            simIDsByName[entry.name] = simID
        }

        state = try SimulationState(
            sims: sims,
            households: [HouseholdState(id: householdID, memberIDs: sims.map(\.id))],
            lots: [LotState(
                id: lotID,
                bounds: GridSize(width: layout.width, height: layout.height),
                placedItems: placedItems
            )]
        )
        placedItemCount = placedItems.count
        self.content = content
        self.simNames = simNames
        self.simIDsByName = simIDsByName
        self.itemNames = itemNames
        self.symbolsByItemID = symbolsByItemID
    }

    func simID(named name: String) -> SimID? {
        simIDsByName[name]
    }

    func displayName(for simID: SimID) -> String {
        simNames[simID] ?? simID.rawValue
    }

    func itemName(for itemID: ItemInstanceID) -> String {
        itemNames[itemID] ?? itemID.rawValue
    }

    func definitionName(_ interaction: InteractionReference) -> String {
        content.catalog.definition(for: interaction.itemDefinitionID)?.identity.name
            ?? interaction.itemDefinitionID.rawValue
    }

    func mapSymbol(for itemID: ItemInstanceID) -> Character {
        symbolsByItemID[itemID] ?? "#"
    }

    /// Sims are numbered in snapshot order; items use a unique lowercase letter.
    func legend(for snapshot: SimulationSnapshot) -> String {
        let sims = snapshot.sims.enumerated().map { "\($0.offset + 1)=\(displayName(for: $0.element.id))" }
        let items = itemNames.sorted { $0.value < $1.value }.map { "\(mapSymbol(for: $0.key))=\($0.value)" }
        return (sims + items).joined(separator: " ")
    }

    /// Converts a layout's motive values, rejecting unknown or missing motives.
    private static func motives(_ values: [String: Double], for name: String) throws -> MotiveLevels {
        var levels: [MotiveType: Double] = [:]
        for (key, value) in values {
            guard let motiveType = MotiveType(rawValue: key) else {
                throw NewbieHouseError.unknownMotive(key, sim: name)
            }
            levels[motiveType] = value
        }
        return try MotiveLevels(levels: levels)
    }
}

private enum NewbieHouseError: Error {
    case missingResource(String)
    case missingValue(String)
    case invalidIdentifier(String)
    case unknownMotive(String, sim: String)
    case packFailedToLoad(folder: String, reason: String)
}
