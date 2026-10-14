import Foundation
import MotiveEngine
import Testing

@Suite("Buffs")
struct BuffTests {
    @Test func ambientRuleAppliesNearbyAmbientItemsOnTheSimsLot() throws {
        let fixture = try makeAmbientFixture()
        let rule = try AmbientBuffRule(id: #require(BuffID("ambient")), radius: 2)

        // The stereo is 2 tiles away and the gem is 4 tiles away.
        let signals = try rule.signals(in: fixture.context(simAt: GridPosition(x: 0, y: 0)))

        #expect(signals == [MotiveSignal(motiveType: .fun, strengthPerSecond: 1)])
    }

    @Test func ambientRuleIncludesHybridItemsAndOrdersByInstanceID() throws {
        let fixture = try makeAmbientFixture()
        let rule = try AmbientBuffRule(id: #require(BuffID("ambient")), radius: 10)

        let signals = try rule.signals(in: fixture.context(simAt: GridPosition(x: 0, y: 0)))

        // "gem" sorts before "stereo"; the non-ambient chair contributes nothing.
        #expect(signals == [
            MotiveSignal(motiveType: .energy, strengthPerSecond: 0.5),
            MotiveSignal(motiveType: .fun, strengthPerSecond: 1),
        ])
    }

    @Test func ambientRuleIgnoresSimsWithoutALotOrPosition() throws {
        let fixture = try makeAmbientFixture()
        let rule = try AmbientBuffRule(id: #require(BuffID("ambient")), radius: 10)
        let offLotSim = SimStateData(
            id: try #require(SimID("visitor")),
            motives: try makeMotiveLevels(),
            posture: .standing
        )

        let offLotContext = BuffContext(sim: offLotSim, lot: nil, itemCatalog: fixture.catalog)
        let mismatchedLotContext = BuffContext(sim: offLotSim, lot: fixture.lot, itemCatalog: fixture.catalog)

        #expect(try rule.signals(in: offLotContext).isEmpty)
        #expect(try rule.signals(in: mismatchedLotContext).isEmpty)
    }

    @Test func ambientRuleRejectsNegativeRadiusAndUnknownDefinitions() throws {
        let id = try #require(BuffID("ambient"))
        #expect(throws: BuffError.invalidRadius) {
            try AmbientBuffRule(id: id, radius: -1)
        }

        let fixture = try makeAmbientFixture()
        let emptyCatalog = try ItemDefinitionCatalog(definitions: [])
        let context = BuffContext(
            sim: try fixture.context(simAt: GridPosition(x: 0, y: 0)).sim,
            lot: fixture.lot,
            itemCatalog: emptyCatalog
        )
        #expect(throws: ItemDefinitionCatalogError.self) {
            try AmbientBuffRule(id: id, radius: 10).signals(in: context)
        }
    }

    @Test func ruleSetsRejectDuplicateIDsAndSortRulesByID() throws {
        let alpha = try #require(BuffID("alpha"))
        let beta = try #require(BuffID("beta"))

        #expect(throws: BuffError.duplicateBuffID(alpha)) {
            try BuffRuleSet(rules: [
                FixedBuffRule(id: alpha, output: []),
                FixedBuffRule(id: alpha, output: []),
            ])
        }

        let ruleSet = try BuffRuleSet(rules: [
            FixedBuffRule(id: beta, output: []),
            FixedBuffRule(id: alpha, output: []),
        ])
        #expect(ruleSet.rules.map(\.id) == [alpha, beta])
        #expect(BuffRuleSet().isEmpty)
    }

    @Test func evaluationOrdersEffectsByIDAndSumsBeforeClamping() throws {
        let alpha = try #require(BuffID("alpha"))
        let beta = try #require(BuffID("beta"))
        let quiet = try #require(BuffID("quiet"))
        let ruleSet = try BuffRuleSet(rules: [
            FixedBuffRule(id: beta, output: [MotiveSignal(motiveType: .fun, strengthPerSecond: -30)]),
            FixedBuffRule(id: quiet, output: []),
            FixedBuffRule(id: alpha, output: [MotiveSignal(motiveType: .fun, strengthPerSecond: 20)]),
        ])
        let context = try makeContext(motives: makeMotiveLevels([.fun: 90]))

        let evaluation = try BuffSystem.evaluate(ruleSet, in: context, overSeconds: 1)

        // 90 + 20 - 30 = 80. Clamping after each rule would give 70 instead.
        #expect(evaluation.motives.level(for: .fun) == 80)
        #expect(evaluation.effects == [
            BuffEffect(buffID: alpha, signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 20)]),
            BuffEffect(buffID: beta, signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: -30)]),
        ])
    }

    @Test func evaluationIsRepeatableAndZeroTimeLeavesMotivesUnchanged() throws {
        let ruleSet = try BuffRuleSet(rules: [
            FixedBuffRule(
                id: #require(BuffID("hunger")),
                output: [MotiveSignal(motiveType: .hunger, strengthPerSecond: 2)]
            ),
        ])
        let context = try makeContext(motives: makeMotiveLevels())

        let first = try BuffSystem.evaluate(ruleSet, in: context, overSeconds: 3)
        let second = try BuffSystem.evaluate(ruleSet, in: context, overSeconds: 3)
        let instant = try BuffSystem.evaluate(ruleSet, in: context, overSeconds: 0)

        #expect(first == second)
        #expect(first.motives.level(for: .hunger) == 56)
        #expect(context.sim.motives.level(for: .hunger) == 50)
        #expect(instant.motives == context.sim.motives)
        #expect(instant.effects == first.effects)
    }

    @Test func evaluationRejectsInvalidTimeAndNonFiniteSignals() throws {
        let id = try #require(BuffID("broken"))
        let broken = try BuffRuleSet(rules: [
            FixedBuffRule(id: id, output: [MotiveSignal(motiveType: .social, strengthPerSecond: .nan)]),
        ])
        let context = try makeContext(motives: makeMotiveLevels())

        #expect(throws: BuffError.nonFiniteSignal(buffID: id, motiveType: .social)) {
            try BuffSystem.evaluate(broken, in: context, overSeconds: 1)
        }
        #expect(throws: MotiveLevelsError.invalidElapsedSeconds) {
            try BuffSystem.evaluate(BuffRuleSet(), in: context, overSeconds: -1)
        }
    }

    @Test func sessionWithoutBuffsEmitsNoBuffEvents() throws {
        let fixture = try makeAmbientFixture()
        var session = try SimulationSession(
            state: fixture.state(simAt: GridPosition(x: 0, y: 0)),
            itemCatalog: fixture.catalog,
            motiveDecayRates: makeDecayRates(1)
        )

        let result = try session.step(bySeconds: 1)
        let sim = try #require(result.snapshot.sims.first)

        #expect(sim.motives.level(for: .fun) == 49)
        #expect(!result.events.contains {
            if case .buffsApplied = $0 { return true }
            return false
        })
    }

    @Test func sessionAppliesBuffsAfterMotiveDecay() throws {
        let fixture = try makeAmbientFixture()
        let buffID = try #require(BuffID("ambient"))
        let simID = try #require(SimID("sim"))
        var session = try SimulationSession(
            state: fixture.state(simAt: GridPosition(x: 0, y: 0)),
            itemCatalog: fixture.catalog,
            motiveDecayRates: makeDecayRates(1),
            buffRules: BuffRuleSet(rules: [AmbientBuffRule(id: buffID, radius: 2)])
        )

        let result = try session.step(bySeconds: 2)
        let decayed = try makeMotiveLevels(Dictionary(
            uniqueKeysWithValues: MotiveType.allCases.map { ($0, 48.0) }
        ))
        let buffed = try makeMotiveLevels(Dictionary(
            uniqueKeysWithValues: MotiveType.allCases.map { ($0, $0 == .fun ? 50.0 : 48.0) }
        ))

        #expect(result.events.prefix(3) == [
            .motivesChanged(simID: simID, motives: decayed),
            .buffsApplied(
                simID: simID,
                effects: [BuffEffect(buffID: buffID, signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 1)])]
            ),
            .motivesChanged(simID: simID, motives: buffed),
        ])
        #expect(session.state.sim(for: simID)?.motives == buffed)
    }

    // MARK: Timed buffs

    @Test(arguments: [0, -1, Double.infinity, .nan])
    func timedBuffsRejectInvalidDurations(durationSeconds: Double) throws {
        let id = try #require(BuffID("fulfilled"))

        #expect(throws: BuffError.invalidDuration(id)) {
            try TimedBuff(id: id, signals: [], durationSeconds: durationSeconds)
        }
    }

    @Test func timedBuffsRejectNonFiniteSignals() throws {
        let id = try #require(BuffID("fulfilled"))

        #expect(throws: BuffError.nonFiniteSignal(buffID: id, motiveType: .fun)) {
            try TimedBuff(
                id: id,
                signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: .infinity)],
                durationSeconds: 1
            )
        }
    }

    @Test func timedBuffsApplyOnlyForTheirRemainingTime() throws {
        let id = try #require(BuffID("fulfilled"))
        let buff = try TimedBuff(
            id: id,
            signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 2)],
            durationSeconds: 3
        )
        let sim = SimStateData(
            id: try #require(SimID("sim")),
            motives: try makeMotiveLevels(),
            posture: .standing,
            timedBuffs: [buff]
        )
        let context = BuffContext(sim: sim, lot: nil, itemCatalog: try ItemDefinitionCatalog(definitions: []))

        let partial = try BuffSystem.evaluate(BuffRuleSet(), in: context, overSeconds: 1)
        let overrun = try BuffSystem.evaluate(BuffRuleSet(), in: context, overSeconds: 10)
        let instant = try BuffSystem.evaluate(BuffRuleSet(), in: context, overSeconds: 0)

        #expect(partial.motives.level(for: .fun) == 52)
        #expect(partial.timedBuffs.map(\.remainingSeconds) == [2])
        #expect(partial.expiredBuffIDs.isEmpty)
        #expect(partial.effects == [BuffEffect(buffID: id, signals: buff.signals)])
        #expect(overrun.motives.level(for: .fun) == 56)
        #expect(overrun.timedBuffs.isEmpty)
        #expect(overrun.expiredBuffIDs == [id])
        #expect(instant.motives == sim.motives)
        #expect(instant.timedBuffs == [buff])
    }

    @Test func sessionAppliesRestartsAndExpiresTimedBuffs() throws {
        let fixture = try makeAmbientFixture()
        let simID = try #require(SimID("sim"))
        let buffID = try #require(BuffID("fulfilled"))
        let buff = try TimedBuff(
            id: buffID,
            signals: [MotiveSignal(motiveType: .social, strengthPerSecond: 1)],
            durationSeconds: 3
        )
        var session = try SimulationSession(
            state: fixture.state(simAt: GridPosition(x: 4, y: 4)),
            itemCatalog: fixture.catalog,
            motiveDecayRates: makeDecayRates(0)
        )

        let started = try session.step(bySeconds: 2, commands: [.applyBuff(simID: simID, buff: buff)])
        #expect(started.events.first == .timedBuffApplied(simID: simID, buff: buff))
        #expect(session.state.sim(for: simID)?.motives.level(for: .social) == 52)
        #expect(session.state.sim(for: simID)?.timedBuffs.map(\.remainingSeconds) == [1])

        // Reapplying restarts the buff instead of stacking a second copy.
        try session.step(bySeconds: 0, commands: [.applyBuff(simID: simID, buff: buff)])
        #expect(session.state.sim(for: simID)?.timedBuffs == [buff])

        let expired = try session.step(bySeconds: 5)
        #expect(session.state.sim(for: simID)?.motives.level(for: .social) == 55)
        #expect(session.state.sim(for: simID)?.timedBuffs.isEmpty == true)
        #expect(expired.events.last == .timedBuffExpired(simID: simID, buffID: buffID))

        let quiet = try session.step(bySeconds: 1)
        #expect(quiet.events.isEmpty)
    }

    @Test func timedBuffCommandsAndStateAreValidated() throws {
        let fixture = try makeAmbientFixture()
        let buff = try TimedBuff(id: #require(BuffID("fulfilled")), signals: [], durationSeconds: 1)
        let state = try fixture.state(simAt: GridPosition(x: 0, y: 0))
        var session = try SimulationSession(
            state: state,
            itemCatalog: fixture.catalog,
            motiveDecayRates: makeDecayRates(0)
        )
        let missing = try #require(SimID("missing"))

        #expect(throws: SimulationSessionError.missingSim(missing)) {
            try session.step(bySeconds: 1, commands: [.applyBuff(simID: missing, buff: buff)])
        }
        #expect(session.state == state)

        let sim = try fixture.sim(at: GridPosition(x: 0, y: 0))
        #expect(throws: SimulationStateError.duplicateTimedBuff(simID: sim.id, buffID: buff.id)) {
            try SimulationState(
                sims: [SimStateData(id: sim.id, motives: sim.motives, posture: .standing, timedBuffs: [buff, buff])],
                households: [],
                lots: []
            )
        }
    }

    // MARK: - Fixtures

    private struct FixedBuffRule: BuffRule {
        let id: BuffID
        let output: [MotiveSignal]

        func signals(in _: BuffContext) throws -> [MotiveSignal] {
            output
        }
    }

    private struct AmbientFixture {
        let catalog: ItemDefinitionCatalog
        let lot: LotState

        func sim(at position: GridPosition) throws -> SimStateData {
            SimStateData(
                id: try #require(SimID("sim")),
                motives: try makeMotiveLevels(),
                posture: .standing,
                currentLotID: lot.id,
                position: position
            )
        }

        func context(simAt position: GridPosition) throws -> BuffContext {
            BuffContext(sim: try sim(at: position), lot: lot, itemCatalog: catalog)
        }

        func state(simAt position: GridPosition) throws -> SimulationState {
            try SimulationState(sims: [sim(at: position)], households: [], lots: [lot])
        }
    }

    /// A 5x5 lot with a hybrid ambient stereo, an ambient gem, and a plain chair.
    private func makeAmbientFixture() throws -> AmbientFixture {
        let stereoID = try #require(ItemDefinitionID("stereo"))
        let gemID = try #require(ItemDefinitionID("gem"))
        let chairID = try #require(ItemDefinitionID("chair"))
        let catalog = try ItemDefinitionCatalog(definitions: [
            ItemDefinition(
                id: stereoID,
                identity: ItemIdentity(name: "Stereo", itemTypes: [.ambient, .recreation]),
                signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 1)]
            ),
            ItemDefinition(
                id: gemID,
                identity: ItemIdentity(name: "Gem", itemTypes: .ambient),
                signals: [MotiveSignal(motiveType: .energy, strengthPerSecond: 0.5)]
            ),
            ItemDefinition(
                id: chairID,
                identity: ItemIdentity(name: "Chair", itemTypes: .chair),
                signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 5)]
            ),
        ])
        let lot = try LotState(
            id: #require(LotID("home")),
            bounds: GridSize(width: 5, height: 5),
            placedItems: [
                PlacedItem(id: #require(ItemInstanceID("stereo")), definitionID: stereoID, position: GridPosition(x: 2, y: 0)),
                PlacedItem(id: #require(ItemInstanceID("gem")), definitionID: gemID, position: GridPosition(x: 2, y: 2)),
                PlacedItem(id: #require(ItemInstanceID("chair")), definitionID: chairID, position: GridPosition(x: 0, y: 1)),
            ]
        )
        return AmbientFixture(catalog: catalog, lot: lot)
    }

    private func makeContext(motives: MotiveLevels) throws -> BuffContext {
        BuffContext(
            sim: SimStateData(id: try #require(SimID("sim")), motives: motives, posture: .standing),
            lot: nil,
            itemCatalog: try ItemDefinitionCatalog(definitions: [])
        )
    }

    private func makeDecayRates(_ rate: Double) throws -> MotiveDecayRates {
        try MotiveDecayRates(ratesPerSecond: Dictionary(
            uniqueKeysWithValues: MotiveType.allCases.map { ($0, rate) }
        ))
    }
}

private func makeMotiveLevels(_ overrides: [MotiveType: Double] = [:]) throws -> MotiveLevels {
    var levels = Dictionary(uniqueKeysWithValues: MotiveType.allCases.map { ($0, 50.0) })
    levels.merge(overrides) { _, override in override }
    return try MotiveLevels(levels: levels)
}
