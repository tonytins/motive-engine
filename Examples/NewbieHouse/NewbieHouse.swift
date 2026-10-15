import Foundation
import MotiveEngine

/// Runs Bob and Betty Newbie through a short simulation, printing events and
/// motive levels as time advances.
///
/// Items come from content packs in the bundled `Content` folder: the `base`
/// pack and the `newbie-extras` mod, which overrides the base television and
/// adds an aquarium. `lot.json` is a `LotLayout`: it only places items and
/// Sims.
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

    static func main() {
        do {
            try run(options: Options(arguments: Array(CommandLine.arguments.dropFirst())))
        } catch {
            FileHandle.standardError.write(Data("NewbieHouse failed: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run(options: Options) throws {
        let content = try ContentLoading.load(
            includingBrokenMod: options.loadsBrokenMod,
            extraPacks: options.extraPackFolders
        )
        let layoutURL = try options.lotURL ?? ContentLoading.bundledURL("lot", extension: "json")
        let layout = try LotLayout(jsonData: Data(contentsOf: layoutURL))
        guard let lotID = LotID("newbie-lot") else {
            throw NewbieHouseError.invalidIdentifier("newbie-lot")
        }

        // A game would warn about items from packs that aren't installed; this
        // example lists them and leaves them off the lot.
        let world = try layout.makeState(lotID: lotID, catalog: content.catalog, missingContent: .skip)
        let missingPacks = Set(world.skippedItems.compactMap {
            $0.definitionID.rawValue.split(separator: ":").first.map(String.init)
        })
        if !missingPacks.isEmpty {
            print("Skipped items from packs that aren't loaded: \(missingPacks.sorted().joined(separator: ", "))\n")
        }

        let narrator = Narrator(labels: Labels(layout: layout, skippedItems: world.skippedItems, catalog: content.catalog))
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

        let start = SimulationSnapshot(state: session.state)
        let placedCount = layout.items.count - world.skippedItems.count
        print("Newbie house: \(layout.size.width)x\(layout.size.height) lot, \(placedCount) items placed")
        narrator.printMap(start)
        narrator.printMotives(start, at: 0)

        // Betty heads straight for the shower at the player's request.
        // Bob is left to his own free will.
        var pendingCommands: [SimulationCommand] = []
        if let betty = SimID("betty"),
           let shower = ItemInstanceID("shower"),
           let takeShower = InteractionDefinitionID("shower")
        {
            pendingCommands.append(.startInteraction(simID: betty, itemInstanceID: shower, interactionDefinitionID: takeShower))
        }

        for stepIndex in 1 ... stepCount {
            let time = Double(stepIndex) * stepSeconds
            let result = try session.step(bySeconds: stepSeconds, commands: pendingCommands)
            pendingCommands = []

            for line in result.events.compactMap(narrator.describe) {
                print("[t=\(Narrator.format(time))s] \(line)")
            }
            if stepIndex.isMultiple(of: summaryInterval) || stepIndex == stepCount {
                narrator.printMap(result.snapshot)
                narrator.printMotives(result.snapshot, at: time)
            }
        }

        if !session.contentHealth.disabledPacks.isEmpty {
            let packs = session.contentHealth.disabledPacks.keys.map(\.rawValue).sorted()
            print("Disabled until re-enabled by the player: \(packs.joined(separator: ", "))")
        }
    }

    private static func buffRules() throws -> BuffRuleSet {
        guard let ambientID = BuffID("ambient") else {
            throw NewbieHouseError.invalidIdentifier("ambient")
        }
        return try BuffRuleSet(rules: [AmbientBuffRule(id: ambientID, radius: 2)])
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
}
