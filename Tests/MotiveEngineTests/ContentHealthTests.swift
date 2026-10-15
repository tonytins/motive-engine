import Foundation
import MotiveEngine
import Testing

private let brokenScript = """
state default
    func stateEntry()
        throw "broken"
    end
end
"""

/// Fails for bored Sims and works for everyone else.
private let moodyScript = """
state default
    func stateEntry()
        if sim.fun < 10
            throw "too bored"
        end
        effect.fulfill("hunger", 3)
    end
end
"""

/// One item per entry, each with an `eat` interaction run by `script`.
/// `written` adds written hunger effects to fall back on.
private func itemsFile(_ entries: [(id: String, script: String, written: Bool)]) -> String {
    let items = entries.map { entry in
        let effects = entry.written ? #", "effects": {"hunger": 1}"# : ""
        return #"""
        {"id": "\#(entry.id)", "name": "\#(entry.id)", "modifiers": ["ambient"],
         "interactions": [{"id": "eat", "name": "Eat", "duration": 60,
                           "advertises": {"hunger": 2}\#(effects), "script": "\#(entry.script)"}]}
        """#
    }
    return #"{"items": [\#(items.joined(separator: ","))]}"#
}

private func manifest(_ id: String, dependencies: [String] = []) -> String {
    let list = dependencies.map { #""\#($0)""# }.joined(separator: ",")
    return #"{"id": "\#(id)", "name": "\#(id)", "version": "1", "format": 1, "dependencies": [\#(list)]}"#
}

private func loadPack(_ id: String, dependencies: [String] = [], items: String? = nil) throws -> ContentPack {
    var files = [
        "pack.json": manifest(id, dependencies: dependencies),
        "scripts/broken.rob": brokenScript,
        "scripts/moody.rob": moodyScript,
    ]
    files["items.json"] = items
    return try ContentPack(loadingFrom: MemorySource(files: files))
}

/// A one-row lot with Sims at the left and the given items to the right.
private struct World {
    let content: ContentComposition
    let lot: LotState
    let sims: [SimStateData]

    /// Sims start with `hunger`; at 100 they want nothing, so free will stays
    /// out of the way of the test's commands.
    init(
        content: ContentComposition,
        items: [String],
        sims simEntries: [(id: String, fun: Double)],
        hunger: Double = 10
    ) throws {
        self.content = content
        let width = simEntries.count + items.count
        lot = try LotState(
            id: #require(LotID("home")),
            bounds: GridSize(width: width, height: 1),
            placedItems: items.enumerated().map { index, definition in
                PlacedItem(
                    id: try #require(ItemInstanceID("item-\(index)")),
                    definitionID: try #require(ItemDefinitionID(definition)),
                    position: GridPosition(x: simEntries.count + index, y: 0)
                )
            }
        )
        let lotID = lot.id
        sims = try simEntries.enumerated().map { index, entry in
            var levels = Dictionary(uniqueKeysWithValues: MotiveType.allCases.map { ($0, 80.0) })
            levels[.hunger] = hunger
            levels[.fun] = entry.fun
            return SimStateData(
                id: try #require(SimID(entry.id)),
                motives: try MotiveLevels(levels: levels),
                posture: .standing,
                currentLotID: lotID,
                position: GridPosition(x: index, y: 0)
            )
        }
    }

    func session(
        policy: ScriptFailurePolicy,
        health: ContentHealth = ContentHealth()
    ) throws -> SimulationSession {
        try SimulationSession(
            state: SimulationState(sims: sims, households: [], lots: [lot]),
            content: content,
            motiveDecayRates: MotiveDecayRates(ratesPerSecond: Dictionary(
                uniqueKeysWithValues: MotiveType.allCases.map { ($0, 0.0) }
            )),
            scriptFailurePolicy: policy,
            contentHealth: health
        )
    }
}

private func eat(_ simID: String, item index: Int) throws -> SimulationCommand {
    .startInteraction(
        simID: try #require(SimID(simID)),
        itemInstanceID: try #require(ItemInstanceID("item-\(index)")),
        interactionDefinitionID: try #require(InteractionDefinitionID("eat"))
    )
}

private func reference(_ definition: String) throws -> InteractionReference {
    InteractionReference(
        itemDefinitionID: try #require(ItemDefinitionID(definition)),
        interactionDefinitionID: try #require(InteractionDefinitionID("eat"))
    )
}

private func packID(_ rawValue: String) throws -> ContentPackID {
    try #require(ContentPackID(rawValue))
}

private func policy(cooldown: Double = 10, failures: Int = 2, perPack: Int = 2) throws -> ScriptFailurePolicy {
    try ScriptFailurePolicy(
        cooldownSeconds: cooldown,
        failuresBeforeDisabling: failures,
        disabledInteractionsBeforeDisablingPack: perPack
    )
}

/// Events about content health, ignoring Sim actions and motives.
private func healthEvents(_ events: [SimulationEvent]) -> [SimulationEvent] {
    events.filter {
        switch $0 {
        case .interactionCoolingDown, .scriptDisabled, .interactionDisabled,
             .packDisabled, .interactionEnabled, .packEnabled:
            true
        default:
            false
        }
    }
}

@Suite("Content health")
struct ContentHealthTests {
    @Test func policiesRejectInvalidValues() {
        #expect(throws: ScriptFailurePolicyError.invalidCooldown) {
            try ScriptFailurePolicy(cooldownSeconds: 0, failuresBeforeDisabling: 1, disabledInteractionsBeforeDisablingPack: 1)
        }
        #expect(throws: ScriptFailurePolicyError.invalidCooldown) {
            try ScriptFailurePolicy(cooldownSeconds: .infinity, failuresBeforeDisabling: 1, disabledInteractionsBeforeDisablingPack: 1)
        }
        #expect(throws: ScriptFailurePolicyError.invalidThreshold) {
            try ScriptFailurePolicy(cooldownSeconds: 1, failuresBeforeDisabling: 0, disabledInteractionsBeforeDisablingPack: 1)
        }
    }

    @Test func failingScriptsCoolDownThenFallBackToWrittenEffects() throws {
        let content = try ContentComposer.compose([
            loadPack("base", items: itemsFile([("fridge", "broken", true)])),
        ])
        var session = try World(content: content, items: ["base:fridge"], sims: [("bob", 80)])
            .session(policy: policy())
        let fridge = try reference("base:fridge")

        let first = try session.step(bySeconds: 0)
        #expect(healthEvents(first.events) == [.interactionCoolingDown(fridge, failureCount: 1, seconds: 10)])

        // Free will skips the fridge while it cools down.
        let waiting = try session.step(bySeconds: 5)
        #expect(!waiting.events.contains { if case .actionChanged = $0 { true } else { false } })

        let second = try session.step(bySeconds: 5)
        #expect(healthEvents(second.events) == [.scriptDisabled(fridge)])
        #expect(session.contentHealth.isScriptDisabled(fridge))

        try session.step(bySeconds: 0)
        let bob = try #require(SimID("bob"))
        let action = try #require(session.state.sim(for: bob)?.activeAction)
        #expect(action.motiveEffects == [MotiveSignal(motiveType: .hunger, strengthPerSecond: 1)])
    }

    @Test func scriptOnlyInteractionsAreDisabledAndCommandsRejected() throws {
        let content = try ContentComposer.compose([
            loadPack("base", items: itemsFile([("fridge", "broken", false)])),
        ])
        var session = try World(content: content, items: ["base:fridge"], sims: [("bob", 80)])
            .session(policy: policy(failures: 1, perPack: 5))
        let fridge = try reference("base:fridge")

        let result = try session.step(bySeconds: 0, commands: [eat("bob", item: 0)])

        #expect(healthEvents(result.events) == [.interactionDisabled(fridge)])
        #expect(throws: SimulationSessionError.interactionDisabled(fridge)) {
            try session.step(bySeconds: 0, commands: [eat("bob", item: 0)])
        }
        let idle = try session.step(bySeconds: 1)
        #expect(!idle.events.contains { if case .actionChanged = $0 { true } else { false } })

        // Re-enabled, the command is accepted again, and the still-broken
        // script disables it again.
        let enabled = try session.step(bySeconds: 0, commands: [.enableInteraction(fridge), eat("bob", item: 0)])
        #expect(healthEvents(enabled.events) == [.interactionEnabled(fridge), .interactionDisabled(fridge)])
        #expect(session.contentHealth.brokenInteractionsByPack[try packID("base")] == [fridge])
    }

    @Test func playerCommandsRetryDuringACooldown() throws {
        let content = try ContentComposer.compose([
            loadPack("base", items: itemsFile([("fridge", "broken", true)])),
        ])
        var session = try World(content: content, items: ["base:fridge"], sims: [("bob", 80)])
            .session(policy: policy(failures: 3))
        let fridge = try reference("base:fridge")

        try session.step(bySeconds: 0, commands: [eat("bob", item: 0)])
        let retried = try session.step(bySeconds: 0, commands: [eat("bob", item: 0)])

        #expect(healthEvents(retried.events) == [.interactionCoolingDown(fridge, failureCount: 2, seconds: 10)])
    }

    @Test func aSuccessClearsTheFailureCount() throws {
        let content = try ContentComposer.compose([
            loadPack("base", items: itemsFile([("fridge", "moody", false), ("oven", "moody", false)])),
        ])
        var session = try World(
            content: content,
            items: ["base:fridge", "base:oven"],
            sims: [("bored", 0), ("happy", 80)],
            hunger: 100
        ).session(policy: policy(failures: 2))

        try session.step(bySeconds: 0, commands: [eat("bored", item: 0)])
        #expect(session.contentHealth.failureCounts[try reference("base:fridge")] == 1)

        try session.step(bySeconds: 0, commands: [eat("happy", item: 0)])
        #expect(session.contentHealth.failureCounts.isEmpty)
    }

    @Test func repeatedBreakageDisablesThePackAndItsDependents() throws {
        let content = try ContentComposer.compose([
            loadPack("base", items: itemsFile([("fridge", "moody", true)])),
            loadPack("mod", dependencies: ["base"], items: itemsFile([("oven", "broken", false), ("grill", "broken", false)])),
            loadPack("addon", dependencies: ["mod"], items: itemsFile([("toaster", "moody", false)])),
        ])
        var session = try World(
            content: content,
            items: ["mod:oven", "mod:grill", "addon:toaster", "base:fridge"],
            sims: [("ann", 80), ("bob", 80), ("cat", 80)],
            hunger: 100
        ).session(policy: policy(failures: 1, perPack: 2))
        let oven = try reference("mod:oven")
        let grill = try reference("mod:grill")

        // Cat starts on the add-on's toaster before anything breaks.
        try session.step(bySeconds: 0, commands: [eat("cat", item: 2)])
        let breaking = try session.step(bySeconds: 0, commands: [eat("ann", item: 0), eat("bob", item: 1)])

        #expect(healthEvents(breaking.events) == [
            .interactionDisabled(oven),
            .interactionDisabled(grill),
            .packDisabled(try packID("mod"), reason: .failingInteractions([oven, grill])),
            .packDisabled(try packID("addon"), reason: .dependencyDisabled(try packID("mod"))),
        ])
        #expect(!session.contentHealth.isPackDisabled(try packID("base")))
        #expect(throws: SimulationSessionError.packDisabled(try packID("addon"))) {
            try session.step(bySeconds: 0, commands: [eat("ann", item: 2)])
        }

        // Commands disabled the packs, so Cat's running action on the add-on's
        // toaster stops in the same step.
        #expect(breaking.events.contains {
            guard case let .actionChanged(simID, action) = $0 else { return false }
            return simID.rawValue == "cat" && action.status == .failed(.itemUnavailable)
        })
    }

    @Test func enablingAPackRestoresItsDependentsAndInteractions() throws {
        let content = try ContentComposer.compose([
            loadPack("base"),
            loadPack("mod", dependencies: ["base"], items: itemsFile([("oven", "broken", false)])),
            loadPack("addon", dependencies: ["mod"]),
        ])
        var session = try World(content: content, items: ["mod:oven"], sims: [("ann", 80)], hunger: 100)
            .session(policy: policy(failures: 1, perPack: 1))
        try session.step(bySeconds: 0, commands: [eat("ann", item: 0)])
        #expect(session.contentHealth.isPackDisabled(try packID("addon")))

        let enabled = try session.step(bySeconds: 0, commands: [.enablePack(packID("mod"))])

        #expect(healthEvents(enabled.events).prefix(2) == [.packEnabled(try packID("mod")), .packEnabled(try packID("addon"))])
        #expect(session.contentHealth.disabledPacks.isEmpty)
        #expect(!session.contentHealth.isInteractionDisabled(try reference("mod:oven")))
    }

    @Test func enablingAPackThatIsNotDisabledResetsItsHistory() throws {
        let content = try ContentComposer.compose([
            loadPack("base", items: itemsFile([("oven", "broken", true)])),
        ])
        var session = try World(content: content, items: ["base:oven"], sims: [("ann", 80)], hunger: 100)
            .session(policy: policy(failures: 3))
        let oven = try reference("base:oven")
        try session.step(bySeconds: 0, commands: [eat("ann", item: 0)])
        #expect(session.contentHealth.failureCounts[oven] == 1)
        #expect(session.contentHealth.isCoolingDown(oven))

        let reset = try session.step(bySeconds: 0, commands: [.enablePack(packID("base"))])

        #expect(healthEvents(reset.events) == [.packEnabled(try packID("base"))])
        #expect(session.contentHealth.failureCounts.isEmpty)
        #expect(!session.contentHealth.isCoolingDown(oven))
    }

    @Test func sessionsWithoutPacksDisableInteractionsOnly() throws {
        let content = try ContentComposer.compose([
            loadPack("base", items: itemsFile([("oven", "broken", false)])),
        ])
        let world = try World(content: content, items: ["base:oven"], sims: [("ann", 80)])
        var session = try SimulationSession(
            state: SimulationState(sims: world.sims, households: [], lots: [world.lot]),
            itemCatalog: content.catalog,
            motiveDecayRates: MotiveDecayRates(ratesPerSecond: Dictionary(
                uniqueKeysWithValues: MotiveType.allCases.map { ($0, 0.0) }
            )),
            scriptFailurePolicy: policy(failures: 1, perPack: 1)
        )

        let result = try session.step(bySeconds: 0, commands: [eat("ann", item: 0)])

        #expect(healthEvents(result.events) == [.interactionDisabled(try reference("base:oven"))])
        #expect(session.contentHealth.disabledPacks.isEmpty)
    }

    @Test func healthSurvivesASaveAndRejectsTamperedValues() throws {
        let content = try ContentComposer.compose([
            loadPack("base", items: itemsFile([("oven", "broken", false), ("fridge", "broken", true)])),
        ])
        let world = try World(content: content, items: ["base:oven", "base:fridge"], sims: [("ann", 80), ("bob", 80)])
        var session = try world.session(policy: policy(failures: 1, perPack: 5))
        try session.step(bySeconds: 0, commands: [eat("ann", item: 0)])

        let saved = try JSONEncoder().encode(session.contentHealth)
        let restored = try JSONDecoder().decode(ContentHealth.self, from: saved)
        let reloaded = try world.session(policy: policy(), health: restored)
        #expect(reloaded.contentHealth.isInteractionDisabled(try reference("base:oven")))

        var tampered = ContentHealth()
        var cooling = try world.session(policy: policy(failures: 5), health: tampered)
        try cooling.step(bySeconds: 0, commands: [eat("bob", item: 1)])
        tampered = cooling.contentHealth
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(tampered)) as? [String: Any])
        var counts = try #require(json["failureCounts"] as? [Any])
        counts[1] = -1
        json["failureCounts"] = counts
        let invalid = try JSONDecoder().decode(ContentHealth.self, from: JSONSerialization.data(withJSONObject: json))

        #expect(throws: SimulationSessionError.invalidContentHealth) {
            try world.session(policy: policy(), health: invalid)
        }
    }
}
