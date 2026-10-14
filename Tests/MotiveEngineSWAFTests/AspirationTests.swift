import Foundation
import MotiveEngine
import MotiveEngineSWAF
import Testing

@Suite("Wants and fears")
struct AspirationTests {
    // MARK: Catalog

    @Test func catalogDecodesEveryTriggerAndWeight() throws {
        let catalog = try WantFearCatalog(jsonData: Data("""
        {"entries": [
          {"id": "get-promoted", "kind": "want", "name": "Get promoted",
           "trigger": {"event": "promoted"}, "requiredTags": ["stage:adult"],
           "weight": 2, "tagWeights": {"aspiration:fortune": 3},
           "aspiration": 20, "rewardPoints": 1500},
          {"id": "sleep", "kind": "want", "name": "Sleep in a bed",
           "trigger": {"interactionCompleted": {"itemDefinition": "bed"}},
           "motiveWeights": {"energy": 4}, "aspiration": 5, "rewardPoints": 100},
          {"id": "starve", "kind": "fear", "name": "Go hungry",
           "trigger": {"motiveBelow": {"motive": "hunger", "level": 10}},
           "aspiration": 10, "rewardPoints": 50}
        ]}
        """.utf8))

        let promoted = try #require(catalog.definition(for: id("get-promoted")))
        #expect(promoted.trigger == .gameEvent(try #require(GameEventID("promoted"))))
        #expect(promoted.requiredTags == [try tag("stage:adult")])
        #expect(promoted.baseWeight == 2)
        #expect(promoted.tagWeights == [try tag("aspiration:fortune"): 3])
        #expect(catalog.definition(for: try id("sleep"))?.trigger == .interactionCompleted(
            itemDefinitionID: ItemDefinitionID("bed"),
            interactionDefinitionID: nil
        ))
        #expect(catalog.definition(for: try id("sleep"))?.motiveWeights == [.energy: 4])
        #expect(catalog.definition(for: try id("starve"))?.trigger == .motiveBelow(.hunger, level: 10))
        #expect(catalog.definitions.map(\.id.rawValue) == ["get-promoted", "sleep", "starve"])
    }

    @Test func schemaExampleDecodes() throws {
        let schemaURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../schema/swaf.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL)) as? [String: Any]
        let example = try #require((schema?["examples"] as? [Any])?.first)

        let catalog = try WantFearCatalog(jsonData: JSONSerialization.data(withJSONObject: example))

        #expect(catalog.definitions.map(\.id.rawValue) == ["get-promoted", "go-hungry", "sleep-in-bed"])
    }

    @Test func catalogRejectsInvalidContent() throws {
        func decode(_ entry: String) throws {
            _ = try WantFearCatalog(jsonData: Data(#"{"entries": [\#(entry)]}"#.utf8))
        }

        #expect(throws: WantFearCatalogError.unknownMotive("thirst")) {
            try decode(#"{"id":"a","kind":"want","name":"A","trigger":{"event":"e"},"motiveWeights":{"thirst":1},"aspiration":1,"rewardPoints":1}"#)
        }
        #expect(throws: WantFearDefinitionError.invalidTrigger(try id("a"))) {
            try decode(#"{"id":"a","kind":"want","name":"A","trigger":{},"aspiration":1,"rewardPoints":1}"#)
        }
        #expect(throws: WantFearDefinitionError.invalidTrigger(try id("a"))) {
            try decode(#"{"id":"a","kind":"want","name":"A","trigger":{"interactionCompleted":{}},"aspiration":1,"rewardPoints":1}"#)
        }
        #expect(throws: WantFearDefinitionError.invalidTrigger(try id("a"))) {
            try decode(#"{"id":"a","kind":"fear","name":"A","trigger":{"motiveBelow":{"motive":"fun","level":120}},"aspiration":1,"rewardPoints":1}"#)
        }
        #expect(throws: WantFearDefinitionError.emptyName(try id("a"))) {
            try decode(#"{"id":"a","kind":"want","name":"","trigger":{"event":"e"},"aspiration":1,"rewardPoints":1}"#)
        }
        #expect(throws: WantFearDefinitionError.invalidWeight(try id("a"))) {
            try decode(#"{"id":"a","kind":"want","name":"A","trigger":{"event":"e"},"weight":-1,"aspiration":1,"rewardPoints":1}"#)
        }
        #expect(throws: WantFearDefinitionError.invalidAspirationPoints(try id("a"))) {
            try decode(#"{"id":"a","kind":"want","name":"A","trigger":{"event":"e"},"aspiration":101,"rewardPoints":1}"#)
        }
        #expect(throws: WantFearDefinitionError.invalidRewardPoints(try id("a"))) {
            try decode(#"{"id":"a","kind":"want","name":"A","trigger":{"event":"e"},"aspiration":1,"rewardPoints":-1}"#)
        }
        #expect(throws: DecodingError.self) {
            try decode(#"{"id":"","kind":"want","name":"A","trigger":{"event":"e"},"aspiration":1,"rewardPoints":1}"#)
        }
        #expect(throws: WantFearCatalogError.duplicateID(try id("a"))) {
            try WantFearCatalog(definitions: [
                want("a", trigger: .gameEvent(event("e"))),
                want("a", trigger: .gameEvent(event("e"))),
            ])
        }
    }

    // MARK: Rolling

    @Test func rollWeightCombinesTagsAndMotiveUrgency() throws {
        let definition = try want(
            "nap",
            trigger: .gameEvent(event("napped")),
            requiredTags: [tag("stage:adult")],
            baseWeight: 1,
            tagWeights: [tag("trait:lazy"): 2, tag("trait:active"): -5],
            motiveWeights: [.energy: 4]
        )
        let adult = try tag("stage:adult")

        #expect(definition.rollWeight(tags: [], motives: try motives()) == 0)
        #expect(definition.rollWeight(tags: [adult], motives: try motives()) == 1 + 4 * 0.5)
        #expect(definition.rollWeight(tags: [adult, try tag("trait:lazy")], motives: try motives([.energy: 0])) == 7)
        #expect(definition.rollWeight(tags: [adult, try tag("trait:active")], motives: try motives()) == 0)
    }

    @Test func rerollIsRepeatableForASeedAndFillsEachSlotOnce() throws {
        let catalog = try makeCatalog()
        let first = try AspirationSystem.reroll(makeState(seed: 7), catalog: catalog, motives: motives())
        let second = try AspirationSystem.reroll(makeState(seed: 7), catalog: catalog, motives: motives())

        #expect(first == second)
        #expect(first.events == [.boardRerolled(simID: try simID())])
        #expect(first.state.wants.count == 2)
        #expect(first.state.fears.count == 1)
        #expect(Set(first.state.wants.map(\.definitionID)).count == 2)
        let wantIDs = Set(catalog.definitions.filter { $0.kind == .want }.map(\.id))
        #expect(first.state.wants.allSatisfy { wantIDs.contains($0.definitionID) })
    }

    @Test func tiredSimsRollTheSleepWant() throws {
        // Only the sleep want has weight when energy is the only urgent need.
        let catalog = try WantFearCatalog(definitions: [
            want("sleep", trigger: .gameEvent(event("slept")), baseWeight: 0, motiveWeights: [.energy: 1]),
            want("party", trigger: .gameEvent(event("partied")), baseWeight: 0, motiveWeights: [.fun: 1]),
        ])
        let profile = try AspirationProfile(wantSlots: 1, fearSlots: 0)
        let state = try AspirationState(simID: simID(), profile: profile, seed: 1)

        let rolled = try AspirationSystem.reroll(
            state,
            catalog: catalog,
            motives: motives([.energy: 10, .fun: 100])
        )

        #expect(rolled.state.wants == [WantFearSlot(definitionID: try id("sleep"))])
    }

    @Test func slotsStayEmptyWhenTooFewEntriesAreEligible() throws {
        let catalog = try WantFearCatalog(definitions: [
            want("teen-only", trigger: .gameEvent(event("e")), requiredTags: [tag("stage:teen")]),
        ])

        let rolled = try AspirationSystem.reroll(makeState(), catalog: catalog, motives: motives())

        #expect(rolled.state.wants.isEmpty)
        #expect(rolled.state.fears.isEmpty)
    }

    // MARK: Fulfillment

    @Test func completedInteractionsFulfillWantsAndRerollThatSlot() throws {
        let catalog = try makeCatalog()
        var state = try makeState()
        state = try board(state, wants: ["sleep", "promoted"], fears: ["starve"])

        let update = try AspirationSystem.observe(
            state,
            events: [completedAction(item: "bed", interaction: "sleep")],
            catalog: catalog,
            motives: motives()
        )

        #expect(update.events == [
            .wantFulfilled(simID: try simID(), wantFearID: try id("sleep"), aspirationChange: 5, rewardPointChange: 100),
        ])
        #expect(update.state.aspiration == 55)
        #expect(update.state.rewardPoints == 100)
        #expect(update.state.wants[1] == WantFearSlot(definitionID: try id("promoted")))
        #expect(update.state.wants[0].definitionID != (try id("sleep")))
        #expect(update.state.wants[0].definitionID != (try id("promoted")))
        #expect(update.state.fears == state.fears)
    }

    @Test func otherSimsAndUnfinishedActionsDoNotFulfillWants() throws {
        let catalog = try makeCatalog()
        let state = try board(makeState(), wants: ["sleep"], fears: [])

        let update = try AspirationSystem.observe(
            state,
            events: [
                completedAction(item: "bed", interaction: "sleep", simID: "someone-else"),
                completedAction(item: "bed", interaction: "sleep", completed: false),
            ],
            catalog: catalog,
            motives: motives()
        )

        #expect(update.events.isEmpty)
        #expect(update.state == state)
    }

    @Test func realizedFearsLowerAspirationAndRewardPointsWithoutGoingNegative() throws {
        let catalog = try makeCatalog()
        var state = try makeState(aspiration: 4, rewardPoints: 20)
        state = try board(state, wants: [], fears: ["starve"])

        let update = try AspirationSystem.observe(state, events: [], catalog: catalog, motives: motives([.hunger: 5]))

        #expect(update.events == [
            .fearRealized(simID: try simID(), wantFearID: try id("starve"), aspirationChange: -4, rewardPointChange: -20),
        ])
        #expect(update.state.aspiration == 0)
        #expect(update.state.rewardPoints == 0)
    }

    @Test func gameEventsAndDirectFulfillmentUseTheSameRules() throws {
        let catalog = try makeCatalog()
        let state = try board(makeState(), wants: ["promoted", "sleep"], fears: [])

        let reported = try AspirationSystem.report(event("promoted"), to: state, catalog: catalog, motives: motives())
        let direct = try AspirationSystem.fulfill(id("promoted"), in: state, catalog: catalog, motives: motives())

        #expect(reported == direct)
        #expect(reported.state.aspiration == 70)
        #expect(throws: AspirationError.notOnBoard(try id("starve"))) {
            try AspirationSystem.fulfill(id("starve"), in: state, catalog: catalog, motives: motives())
        }
        #expect(try AspirationSystem.report(event("unrelated"), to: state, catalog: catalog, motives: motives()).state == state)
    }

    @Test func untrackedSimsEarnPointsWithoutMovingTheBar() throws {
        let catalog = try makeCatalog()
        let profile = try AspirationProfile(wantSlots: 2, fearSlots: 1, tracksAspiration: false)
        let state = try board(
            AspirationState(simID: simID(), profile: profile, seed: 1),
            wants: ["promoted"],
            fears: []
        )

        let update = try AspirationSystem.report(event("promoted"), to: state, catalog: catalog, motives: motives())
        let decayed = try AspirationSystem.decay(state, ratePerSecond: 1, overSeconds: 10)

        #expect(update.state.aspiration == 50)
        #expect(update.state.rewardPoints == 1500)
        #expect(decayed.aspiration == 50)
    }

    // MARK: Locking and decay

    @Test func lockedEntriesSurviveRerollsUntilFulfilled() throws {
        let catalog = try makeCatalog()
        var state = try board(makeState(), wants: ["sleep", "promoted"], fears: ["starve"])
        state = try AspirationSystem.lock(id("promoted"), in: state)

        #expect(throws: AspirationError.lockLimitReached) {
            try AspirationSystem.lock(id("sleep"), in: state)
        }
        #expect(try AspirationSystem.lock(id("promoted"), in: state) == state)

        for _ in 0 ..< 5 {
            state = try AspirationSystem.reroll(state, catalog: catalog, motives: motives()).state
            #expect(state.wants.first == WantFearSlot(definitionID: try id("promoted"), isLocked: true))
        }

        let fulfilled = try AspirationSystem.report(event("promoted"), to: state, catalog: catalog, motives: motives())
        #expect(!fulfilled.state.wants.contains { $0.isLocked })

        let unlocked = try AspirationSystem.unlock(id("promoted"), in: state)
        #expect(!unlocked.wants.contains { $0.isLocked })
        #expect(throws: AspirationError.notOnBoard(try id("not-shown"))) {
            try AspirationSystem.unlock(id("not-shown"), in: state)
        }
    }

    @Test func lockedEntriesAreKeptWhenSlotsShrink() throws {
        let catalog = try makeCatalog()
        var state = try board(makeState(), wants: ["sleep", "promoted"], fears: [])
        state = try AspirationSystem.lock(id("sleep"), in: state)
        state.profile = try AspirationProfile(wantSlots: 0, fearSlots: 0)

        let rerolled = try AspirationSystem.reroll(state, catalog: catalog, motives: motives())

        #expect(rerolled.state.wants == [WantFearSlot(definitionID: try id("sleep"), isLocked: true)])
    }

    @Test func aspirationDecaysAndRejectsInvalidInput() throws {
        let state = try makeState(aspiration: 10)

        #expect(try AspirationSystem.decay(state, ratePerSecond: 0.5, overSeconds: 10).aspiration == 5)
        #expect(try AspirationSystem.decay(state, ratePerSecond: 5, overSeconds: 10).aspiration == 0)
        #expect(throws: AspirationError.invalidDecay) {
            try AspirationSystem.decay(state, ratePerSecond: -1, overSeconds: 1)
        }
        #expect(throws: AspirationError.invalidDecay) {
            try AspirationSystem.decay(state, ratePerSecond: 1, overSeconds: .infinity)
        }
    }

    @Test func stateAndProfileRejectInvalidValues() throws {
        #expect(throws: AspirationError.invalidProfile) {
            try AspirationProfile(wantSlots: -1)
        }
        #expect(throws: AspirationError.invalidAspiration) {
            try makeState(aspiration: 101)
        }
        #expect(throws: AspirationError.invalidRewardPoints) {
            try makeState(rewardPoints: -1)
        }

        let catalog = try makeCatalog()
        let state = try board(makeState(), wants: ["sleep"], fears: [])
        let emptyCatalog = try WantFearCatalog(definitions: [])
        #expect(throws: AspirationError.missingDefinition(try id("sleep"))) {
            try AspirationSystem.observe(state, events: [], catalog: emptyCatalog, motives: motives())
        }

        let misfiled = try board(makeState(), wants: ["starve"], fears: [])
        #expect(throws: AspirationError.kindMismatch(try id("starve"))) {
            try AspirationSystem.observe(misfiled, events: [], catalog: catalog, motives: motives())
        }
        #expect(throws: AspirationError.duplicateBoardEntry(try id("sleep"))) {
            try AspirationState(
                simID: simID(),
                profile: AspirationProfile(),
                wants: [WantFearSlot(definitionID: id("sleep"))],
                fears: [WantFearSlot(definitionID: id("sleep"))],
                seed: 1
            )
        }
    }

    // MARK: Wish mode

    @Test func wishModeFulfillsOnlyPromisedEntries() throws {
        let catalog = try makeCatalog()
        let profile = try wishProfile()
        var state = try AspirationState(
            simID: simID(),
            profile: profile,
            wants: [WantFearSlot(definitionID: id("sleep")), WantFearSlot(definitionID: id("promoted"))],
            seed: 1
        )

        let unpromised = try AspirationSystem.report(event("promoted"), to: state, catalog: catalog, motives: motives())
        #expect(unpromised.events.isEmpty)
        #expect(unpromised.state == state)
        #expect(try AspirationSystem.fulfill(id("promoted"), in: state, catalog: catalog, motives: motives()).state == state)

        state = try AspirationSystem.lock(id("promoted"), in: state)
        let promised = try AspirationSystem.report(event("promoted"), to: state, catalog: catalog, motives: motives())

        #expect(promised.events == [
            .wantFulfilled(simID: try simID(), wantFearID: try id("promoted"), aspirationChange: 0, rewardPointChange: 1500),
        ])
        #expect(promised.state.aspiration == 50)
    }

    @Test func unpromisedOffersExpireAndLeaveTheirSlotEmpty() throws {
        var state = try AspirationState(
            simID: simID(),
            profile: wishProfile(),
            wants: [WantFearSlot(definitionID: id("sleep")), WantFearSlot(definitionID: id("promoted"))],
            seed: 1
        )
        state = try AspirationSystem.lock(id("promoted"), in: state)

        let early = try AspirationSystem.advance(state, bySeconds: 9)
        #expect(early.events.isEmpty)
        #expect(early.state.wants.map(\.ageSeconds) == [9, 9])

        let expired = try AspirationSystem.advance(early.state, bySeconds: 1)
        #expect(expired.events == [.offerExpired(simID: try simID(), wantFearID: try id("sleep"))])
        #expect(expired.state.wants == [WantFearSlot(definitionID: try id("promoted"), isLocked: true, ageSeconds: 10)])

        let refilled = try AspirationSystem.reroll(expired.state, catalog: makeCatalog(), motives: motives())
        #expect(refilled.state.wants.count == 2)
        #expect(refilled.state.wants.first?.ageSeconds == 10)
        #expect(refilled.state.wants.last?.ageSeconds == 0)
    }

    @Test func entriesOnlyAgeWithoutAnOfferLifetime() throws {
        let state = try board(makeState(), wants: ["sleep"], fears: [])

        let update = try AspirationSystem.advance(state, bySeconds: 1_000)

        #expect(update.events.isEmpty)
        #expect(update.state.wants == [WantFearSlot(definitionID: try id("sleep"), ageSeconds: 1_000)])
        #expect(throws: AspirationError.invalidElapsedTime) {
            try AspirationSystem.advance(state, bySeconds: -1)
        }
    }

    @Test func cancelRemovesPromisedAndOfferedEntries() throws {
        var state = try board(makeState(), wants: ["sleep", "promoted"], fears: ["starve"])
        state = try AspirationSystem.lock(id("promoted"), in: state)

        state = try AspirationSystem.cancel(id("promoted"), in: state)
        state = try AspirationSystem.cancel(id("starve"), in: state)

        #expect(state.wants == [WantFearSlot(definitionID: try id("sleep"))])
        #expect(state.fears.isEmpty)
        #expect(throws: AspirationError.notOnBoard(try id("promoted"))) {
            try AspirationSystem.cancel(id("promoted"), in: state)
        }
    }

    @Test func fulfilledWishesGrantTheFulfillmentBuff() throws {
        let catalog = try makeCatalog()
        let buff = try TimedBuff(
            id: #require(BuffID("fulfilled")),
            signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 1)],
            durationSeconds: 60
        )
        let profile = try AspirationProfile(wantSlots: 2, fearSlots: 1, fulfillmentBuff: buff)
        let state = try AspirationState(
            simID: simID(),
            profile: profile,
            wants: [WantFearSlot(definitionID: id("sleep")), WantFearSlot(definitionID: id("promoted"))],
            fears: [WantFearSlot(definitionID: id("starve"))],
            seed: 1
        )

        // Two wants fulfilled together grant the buff once.
        let wants = try AspirationSystem.observe(
            state,
            events: [completedAction(item: "bed", interaction: "sleep")],
            catalog: catalog,
            motives: motives()
        )
        let both = try AspirationSystem.report(event("promoted"), to: wants.state, catalog: catalog, motives: motives())
        let fear = try AspirationSystem.observe(state, events: [], catalog: catalog, motives: motives([.hunger: 5]))

        #expect(wants.grantedBuffs == [buff])
        #expect(wants.commands == [.applyBuff(simID: try simID(), buff: buff)])
        #expect(both.grantedBuffs == [buff])
        #expect(fear.grantedBuffs.isEmpty)
        #expect(try AspirationSystem.reroll(state, catalog: catalog, motives: motives()).commands.isEmpty)
    }

    @Test func fulfillmentBuffCommandsDriveTheSession() throws {
        let simID = try simID()
        let buff = try TimedBuff(
            id: #require(BuffID("fulfilled")),
            signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 1)],
            durationSeconds: 60
        )
        let state = try AspirationState(
            simID: simID,
            profile: AspirationProfile(wantSlots: 1, fearSlots: 0, fulfillmentBuff: buff),
            wants: [WantFearSlot(definitionID: id("promoted"))],
            seed: 1
        )
        let update = try AspirationSystem.report(event("promoted"), to: state, catalog: makeCatalog(), motives: motives())
        var session = try SimulationSession(
            state: SimulationState(
                sims: [SimStateData(id: simID, motives: motives(), posture: .standing)],
                households: [],
                lots: []
            ),
            itemCatalog: ItemDefinitionCatalog(definitions: []),
            motiveDecayRates: MotiveDecayRates(ratesPerSecond: Dictionary(
                uniqueKeysWithValues: MotiveType.allCases.map { ($0, 0.0) }
            ))
        )

        try session.step(bySeconds: 10, commands: update.commands)

        #expect(session.state.sim(for: simID)?.motives.level(for: .fun) == 60)
    }

    @Test func wishProfilesRejectInvalidLifetimesAndRestoredAges() throws {
        #expect(throws: AspirationError.invalidProfile) {
            try AspirationProfile(offerLifetimeSeconds: 0)
        }
        #expect(throws: AspirationError.invalidProfile) {
            try AspirationProfile(offerLifetimeSeconds: .infinity)
        }
        #expect(throws: AspirationError.invalidSlotAge(try id("sleep"))) {
            try AspirationState(
                simID: simID(),
                profile: AspirationProfile(),
                wants: [WantFearSlot(definitionID: id("sleep"), ageSeconds: -1)],
                seed: 1
            )
        }
    }

    // MARK: - Fixtures

    /// Sims 3-style wishes: no fears or aspiration bar, four promises, and
    /// offers that expire after ten seconds.
    private func wishProfile() throws -> AspirationProfile {
        try AspirationProfile(
            wantSlots: 2,
            fearSlots: 0,
            lockLimit: 4,
            tracksAspiration: false,
            requiresPromise: true,
            offerLifetimeSeconds: 10
        )
    }

    /// Three wants and two fears, with simple triggers.
    private func makeCatalog() throws -> WantFearCatalog {
        try WantFearCatalog(definitions: [
            want(
                "sleep",
                trigger: .interactionCompleted(itemDefinitionID: ItemDefinitionID("bed"), interactionDefinitionID: nil),
                aspirationPoints: 5,
                rewardPoints: 100
            ),
            want("promoted", trigger: .gameEvent(event("promoted")), aspirationPoints: 20, rewardPoints: 1500),
            want("chat", trigger: .gameEvent(event("chatted"))),
            WantFearDefinition(
                id: id("starve"),
                kind: .fear,
                name: "Go hungry",
                trigger: .motiveBelow(.hunger, level: 10),
                aspirationPoints: 10,
                rewardPoints: 50
            ),
            WantFearDefinition(
                id: id("starve-twice"),
                kind: .fear,
                name: "Go hungry again",
                trigger: .motiveBelow(.hunger, level: 1),
                aspirationPoints: 10,
                rewardPoints: 50
            ),
        ])
    }

    private func want(
        _ rawID: String,
        trigger: WantFearTrigger,
        requiredTags: Set<SWAFTag> = [],
        baseWeight: Double = 1,
        tagWeights: [SWAFTag: Double] = [:],
        motiveWeights: [MotiveType: Double] = [:],
        aspirationPoints: Double = 1,
        rewardPoints: Int = 1
    ) throws -> WantFearDefinition {
        try WantFearDefinition(
            id: id(rawID),
            kind: .want,
            name: rawID,
            trigger: trigger,
            requiredTags: requiredTags,
            baseWeight: baseWeight,
            tagWeights: tagWeights,
            motiveWeights: motiveWeights,
            aspirationPoints: aspirationPoints,
            rewardPoints: rewardPoints
        )
    }

    private func makeState(aspiration: Double = 50, rewardPoints: Int = 0, seed: UInt64 = 1) throws -> AspirationState {
        try AspirationState(
            simID: simID(),
            profile: AspirationProfile(wantSlots: 2, fearSlots: 1),
            aspiration: aspiration,
            rewardPoints: rewardPoints,
            seed: seed
        )
    }

    /// Restores a known board, as a game would when loading a save.
    private func board(
        _ state: AspirationState,
        wants: [String],
        fears: [String]
    ) throws -> AspirationState {
        try AspirationState(
            simID: state.simID,
            profile: state.profile,
            wants: wants.map { WantFearSlot(definitionID: try id($0)) },
            fears: fears.map { WantFearSlot(definitionID: try id($0)) },
            aspiration: state.aspiration,
            rewardPoints: state.rewardPoints,
            seed: 1
        )
    }

    private func completedAction(
        item: String,
        interaction: String,
        simID rawSimID: String = "sim",
        completed: Bool = true
    ) throws -> SimulationEvent {
        let definitionID = try #require(ItemDefinitionID(item))
        let catalog = try ItemDefinitionCatalog(definitions: [
            ItemDefinition(
                id: definitionID,
                identity: ItemIdentity(name: item, itemTypes: .bed),
                signals: [],
                interactions: [
                    InteractionDefinition(
                        id: #require(InteractionDefinitionID(interaction)),
                        name: interaction,
                        advertisedBenefits: [],
                        motiveEffects: [],
                        durationSeconds: 1
                    ),
                ]
            ),
        ])
        let placed = PlacedItem(
            id: try #require(ItemInstanceID("\(item)-1")),
            definitionID: definitionID,
            position: GridPosition(x: 0, y: 0)
        )
        let offer = try #require(catalog.interactionOffers(for: placed).first)
        let started = InteractionActionSystem.start(offer, initiatedBy: .autonomy)
        let action = completed
            ? try InteractionActionSystem.advance(started, motives: motives(), bySeconds: 1).action
            : started
        return .actionChanged(simID: try #require(SimID(rawSimID)), action: action)
    }

    private func motives(_ overrides: [MotiveType: Double] = [:]) throws -> MotiveLevels {
        var levels = Dictionary(uniqueKeysWithValues: MotiveType.allCases.map { ($0, 50.0) })
        levels.merge(overrides) { _, override in override }
        return try MotiveLevels(levels: levels)
    }

    private func simID() throws -> SimID {
        try #require(SimID("sim"))
    }

    private func id(_ rawValue: String) throws -> WantFearID {
        try #require(WantFearID(rawValue))
    }

    private func tag(_ rawValue: String) throws -> SWAFTag {
        try #require(SWAFTag(rawValue))
    }

    private func event(_ rawValue: String) throws -> GameEventID {
        try #require(GameEventID(rawValue))
    }
}
