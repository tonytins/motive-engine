import Foundation
import MotiveEngine
import Testing

/// Hunger-scaled eating: 3 per second when starving, 1 otherwise.
private let hungerScaledScript = """
state default
    func stateEntry()
        if sim.hunger < 30
            effect.fulfill("hunger", 3)
        else
            effect.fulfill("hunger", 1)
        end
    end
end
"""

private let outOfFood = InteractionScriptFailure.runtime(RuntimeError(message: "out of food"))

private let brokenScript = """
state default
    func stateEntry()
        throw "out of food"
    end
end
"""

@Suite("Scripted interactions in a session")
struct ScriptedSessionTests {
    @Test func scriptEffectsReplaceWrittenEffectsAndStayFixedForTheAction() throws {
        // The written fun effect is ignored because the script replaces it.
        let fixture = try makeFixture(items: [
            ScriptedItem(name: "fridge", x: 1, script: hungerScaledScript, writtenEffect: .fun),
        ])
        var session = try fixture.session(hunger: 20)

        let started = try session.step(bySeconds: 0, commands: [fixture.command("fridge")])
        let action = try #require(session.state.sim(for: fixture.simID)?.activeAction)
        #expect(action.motiveEffects == [MotiveSignal(motiveType: .hunger, strengthPerSecond: 3)])
        #expect(started.events.contains(.actionChanged(simID: fixture.simID, action: action)))

        // Hunger passes 30 mid-action, but the effects chosen at the start remain.
        try session.step(bySeconds: 5)
        let sim = try #require(session.state.sim(for: fixture.simID))
        #expect(sim.motives.level(for: .hunger) == 35)
        #expect(sim.motives.level(for: .fun) == 50)
        #expect(sim.activeAction?.motiveEffects == action.motiveEffects)
    }

    @Test func failedScriptsFailTheCommandedActionWithoutStoppingTheStep() throws {
        let fixture = try makeFixture(items: [
            ScriptedItem(name: "fridge", x: 1, script: brokenScript),
        ])
        var session = try fixture.session(hunger: 20, decayRate: 1)

        let result = try session.step(bySeconds: 1, commands: [fixture.command("fridge")])

        let failure = result.events.compactMap { event -> InteractionActionStatus? in
            guard case let .actionChanged(_, action) = event else { return nil }
            return action.status
        }
        #expect(failure == [.failed(.scriptFailed(outOfFood))])
        let sim = try #require(session.state.sim(for: fixture.simID))
        #expect(sim.activeAction == nil)
        #expect(sim.motives.level(for: .fun) == 49)
    }

    @Test func autonomyReportsAFailedScriptAndChoosesTheNextUsefulOffer() throws {
        // The broken item advertises more, so free will tries it first.
        let fixture = try makeFixture(items: [
            ScriptedItem(name: "broken-fridge", x: 1, script: brokenScript, advertised: 5),
            ScriptedItem(name: "fridge", x: 3, script: hungerScaledScript, advertised: 1),
        ])
        var session = try fixture.session(hunger: 20)

        let result = try session.step(bySeconds: 0)

        let attempts = result.events.compactMap { event -> (String, InteractionActionStatus)? in
            guard case let .actionChanged(_, action) = event else { return nil }
            return (action.offer.itemInstanceID.rawValue, action.status)
        }
        #expect(attempts.map(\.0) == ["broken-fridge", "fridge"])
        #expect(attempts.map(\.1) == [.failed(.scriptFailed(outOfFood)), .running])
        #expect(session.state.sim(for: fixture.simID)?.activeAction?.offer.itemInstanceID.rawValue == "fridge")
    }

    @Test func invalidRuntimeEffectsAreReportedAsTypedFailures() throws {
        let fixture = try makeFixture(items: [
            ScriptedItem(name: "fridge", x: 1, script: """
            state default
                func stateEntry()
                    val motive = "thirst"
                    effect.fulfill(motive, 1)
                end
            end
            """),
        ])
        var session = try fixture.session(hunger: 20)

        let result = try session.step(bySeconds: 0, commands: [fixture.command("fridge")])

        #expect(result.events.contains {
            guard case let .actionChanged(_, action) = $0 else { return false }
            return action.status == .failed(.scriptFailed(.invalidEffect(.unknownMotive("thirst"))))
        })
    }

    @Test func actionsWithoutScriptsKeepTheirWrittenEffects() throws {
        let fixture = try makeFixture(items: [
            ScriptedItem(name: "fridge", x: 1, script: nil, writtenEffect: .hunger),
        ])
        var session = try fixture.session(hunger: 20)

        try session.step(bySeconds: 0, commands: [fixture.command("fridge")])

        #expect(session.state.sim(for: fixture.simID)?.activeAction?.motiveEffects == [
            MotiveSignal(motiveType: .hunger, strengthPerSecond: 2),
        ])
    }

    @Test func offersCarryTheirInteractionScript() throws {
        let script = try InteractionScript(source: hungerScaledScript)
        let fixture = try makeFixture(items: [
            ScriptedItem(name: "fridge", x: 1, script: hungerScaledScript),
        ])
        let item = try #require(fixture.lot.placedItems.first)

        let offer = try #require(fixture.catalog.interactionOffers(for: item).first)

        #expect(offer.script == script)
    }
}

// MARK: - Fixtures

private struct ScriptedItem {
    let name: String
    let x: Int
    let script: String?
    var writtenEffect: MotiveType = .hunger
    var advertised: Double = 2
}

private struct ScriptedFixture {
    let simID: SimID
    let lot: LotState
    let catalog: ItemDefinitionCatalog
    let interactionID: InteractionDefinitionID

    func session(hunger: Double, decayRate: Double = 0) throws -> SimulationSession {
        var levels = Dictionary(uniqueKeysWithValues: MotiveType.allCases.map { ($0, 50.0) })
        levels[.hunger] = hunger
        let sim = SimStateData(
            id: simID,
            motives: try MotiveLevels(levels: levels),
            posture: .standing,
            currentLotID: lot.id,
            position: GridPosition(x: 0, y: 0)
        )
        return try SimulationSession(
            state: SimulationState(sims: [sim], households: [], lots: [lot]),
            itemCatalog: catalog,
            motiveDecayRates: MotiveDecayRates(ratesPerSecond: Dictionary(
                uniqueKeysWithValues: MotiveType.allCases.map { ($0, decayRate) }
            ))
        )
    }

    func command(_ itemName: String) throws -> SimulationCommand {
        .startInteraction(
            simID: simID,
            itemInstanceID: try #require(ItemInstanceID(itemName)),
            interactionDefinitionID: interactionID
        )
    }
}

/// A 5x1 lot with the Sim at (0, 0) and non-blocking items along the row.
private func makeFixture(items: [ScriptedItem]) throws -> ScriptedFixture {
    let interactionID = try #require(InteractionDefinitionID("eat"))
    let definitions = try items.map { item in
        try ItemDefinition(
            id: #require(ItemDefinitionID(item.name)),
            identity: ItemIdentity(name: item.name, itemTypes: .ambient),
            signals: [],
            interactions: [
                InteractionDefinition(
                    id: interactionID,
                    name: "Eat",
                    advertisedBenefits: [
                        MotiveBenefit(motiveType: .hunger, expectedStrengthPerSecond: item.advertised),
                    ],
                    motiveEffects: [MotiveSignal(motiveType: item.writtenEffect, strengthPerSecond: 2)],
                    durationSeconds: 60,
                    script: item.script.map { try InteractionScript(source: $0) }
                ),
            ]
        )
    }
    let placedItems = try items.map { item in
        PlacedItem(
            id: try #require(ItemInstanceID(item.name)),
            definitionID: try #require(ItemDefinitionID(item.name)),
            position: GridPosition(x: item.x, y: 0)
        )
    }
    return ScriptedFixture(
        simID: try #require(SimID("bob")),
        lot: try LotState(id: #require(LotID("home")), bounds: GridSize(width: 5, height: 1), placedItems: placedItems),
        catalog: try ItemDefinitionCatalog(definitions: definitions),
        interactionID: interactionID
    )
}
