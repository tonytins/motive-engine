import Foundation
import MotiveEngine
import Testing

@Suite("Optional extensions")
struct OptionalExtensionTests {
    @Test func sessionCompletesAutonomousActionsWithoutExtensions() throws {
        let fixture = try makeFixture()
        var session = try SimulationSession(
            state: fixture.state,
            itemCatalog: fixture.catalog,
            motiveDecayRates: fixture.decayRates
        )

        var events: [SimulationEvent] = []
        for _ in 0 ..< 8 {
            events += try session.step(bySeconds: 1).events
        }

        #expect(events.contains {
            if case let .actionChanged(_, action) = $0 {
                return action.initiator == .autonomy && action.status == .completed
            }
            return false
        })
        #expect(events.contains {
            if case .positionChanged = $0 { return true }
            return false
        })
        #expect(!events.contains {
            if case .buffsApplied = $0 { return true }
            return false
        })
        let sim = try #require(session.state.sim(for: fixture.simID))
        #expect(sim.motives.level(for: .hunger) > 20)
    }

    @Test func emptyAndInertBuffRulesMatchASessionWithoutBuffs() throws {
        let fixture = try makeFixture()
        // The lot has no ambient items, so this rule never applies.
        let inertRules = try BuffRuleSet(rules: [
            AmbientBuffRule(id: #require(BuffID("ambient")), radius: 10),
        ])
        var sessions = try [
            SimulationSession(
                state: fixture.state,
                itemCatalog: fixture.catalog,
                motiveDecayRates: fixture.decayRates
            ),
            SimulationSession(
                state: fixture.state,
                itemCatalog: fixture.catalog,
                motiveDecayRates: fixture.decayRates,
                buffRules: BuffRuleSet()
            ),
            SimulationSession(
                state: fixture.state,
                itemCatalog: fixture.catalog,
                motiveDecayRates: fixture.decayRates,
                buffRules: inertRules
            ),
        ]

        for _ in 0 ..< 8 {
            let results = try sessions.indices.map { try sessions[$0].step(bySeconds: 1) }
            #expect(results.allSatisfy { $0 == results[0] })
        }
    }

    @Test func authoredEffectsNeedNoScript() throws {
        let fixture = try makeFixture()
        let offer = try #require(fixture.catalog.interactionOffers(for: fixture.item).first)
        let sim = try #require(fixture.state.sim(for: fixture.simID))

        let action = InteractionActionSystem.start(offer, initiatedBy: .playerCommand)
        let update = try InteractionActionSystem.advance(action, motives: sim.motives, bySeconds: 2)

        #expect(update.action.status == .completed)
        #expect(update.motives.level(for: .hunger) == 30)
    }

    // MARK: - Fixtures

    private struct Fixture {
        let simID: SimID
        let item: PlacedItem
        let catalog: ItemDefinitionCatalog
        let state: SimulationState
        let decayRates: MotiveDecayRates
    }

    /// A hungry Sim two tiles from a fridge that offers a two-second snack.
    private func makeFixture() throws -> Fixture {
        let simID = try #require(SimID("sim"))
        let lotID = try #require(LotID("home"))
        let definitionID = try #require(ItemDefinitionID("fridge"))
        let definition = try ItemDefinition(
            id: definitionID,
            identity: ItemIdentity(name: "Fridge", itemTypes: .appliance),
            signals: [],
            interactions: [
                InteractionDefinition(
                    id: #require(InteractionDefinitionID("snack")),
                    name: "Snack",
                    advertisedBenefits: [MotiveBenefit(motiveType: .hunger, expectedStrengthPerSecond: 5)],
                    motiveEffects: [MotiveSignal(motiveType: .hunger, strengthPerSecond: 5)],
                    durationSeconds: 2
                ),
            ]
        )
        let item = PlacedItem(
            id: try #require(ItemInstanceID("fridge-1")),
            definitionID: definitionID,
            position: GridPosition(x: 3, y: 0)
        )
        var levels = Dictionary(uniqueKeysWithValues: MotiveType.allCases.map { ($0, 80.0) })
        levels[.hunger] = 20
        let sim = SimStateData(
            id: simID,
            motives: try MotiveLevels(levels: levels),
            posture: .standing,
            currentLotID: lotID,
            position: GridPosition(x: 0, y: 0)
        )
        let lot = try LotState(id: lotID, bounds: GridSize(width: 4, height: 2), placedItems: [item])
        return Fixture(
            simID: simID,
            item: item,
            catalog: try ItemDefinitionCatalog(definitions: [definition]),
            state: try SimulationState(sims: [sim], households: [], lots: [lot]),
            decayRates: try MotiveDecayRates(ratesPerSecond: Dictionary(
                uniqueKeysWithValues: MotiveType.allCases.map { ($0, 0.5) }
            ))
        )
    }
}
