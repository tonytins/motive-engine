import Foundation
import MotiveEngine
import Testing

@Suite("Public Motive API")
struct PublicMotiveAPITests {
    @Test func clientsCanConstructAndTransformMotiveData() throws {
        let levels = try MotiveLevels(
            levels: Dictionary(
                uniqueKeysWithValues: MotiveType.allCases.map { ($0, 50.0) }
            )
        )
        let decayRates = try MotiveDecayRates(
            ratesPerSecond: Dictionary(
                uniqueKeysWithValues: MotiveType.allCases.map { ($0, 1.0) }
            )
        )

        let decayed = try MotiveSystem.decay(levels, using: decayRates, overSeconds: 5)
        let fulfilled = try MotiveSystem.fulfill(
            decayed,
            with: [MotiveSignal(motiveType: .hunger, strengthPerSecond: 2)],
            overSeconds: 5
        )

        #expect(fulfilled.level(for: .hunger) == 55)
        #expect(fulfilled.level(for: .energy) == 45)
    }

    @Test func definitionCatalogAndPlacedInstancesUseDifferentIDs() throws {
        let definitionID = try #require(ItemDefinitionID("small-chair"))
        let interactionID = try #require(InteractionDefinitionID("sit-and-read"))
        let interaction = try InteractionDefinition(
            id: interactionID,
            name: "Sit and read",
            advertisedBenefits: [
                MotiveBenefit(motiveType: .fun, expectedStrengthPerSecond: 2)
            ],
            motiveEffects: [
                MotiveSignal(motiveType: .fun, strengthPerSecond: 1),
                MotiveSignal(motiveType: .energy, strengthPerSecond: -0.25),
            ],
            durationSeconds: 10
        )
        let definition = ItemDefinition(
            id: definitionID,
            identity: ItemIdentity(name: "Small Chair", itemTypes: .chair),
            signals: [],
            interactions: [interaction]
        )
        let catalog = try ItemDefinitionCatalog(definitions: [definition])
        let firstInstance = PlacedItem(
            id: try #require(ItemInstanceID("living-room-chair")),
            definitionID: definitionID,
            position: GridPosition(x: 2, y: 1)
        )
        let secondInstance = PlacedItem(
            id: try #require(ItemInstanceID("bedroom-chair")),
            definitionID: definitionID,
            position: GridPosition(x: 4, y: 3)
        )

        #expect(catalog.definition(for: firstInstance.definitionID) == definition)
        let firstOffers = try catalog.interactionOffers(for: firstInstance)
        let secondOffers = try catalog.interactionOffers(for: secondInstance)
        #expect(firstOffers.count == 1)
        #expect(firstOffers[0].itemInstanceID == firstInstance.id)
        #expect(firstOffers[0].itemDefinitionID == definitionID)
        #expect(firstOffers[0].interactionDefinitionID == interactionID)
        #expect(firstOffers[0].name == interaction.name)
        #expect(firstOffers[0].advertisedBenefits == interaction.advertisedBenefits)
        #expect(firstOffers[0].motiveEffects == interaction.motiveEffects)
        #expect(firstOffers[0].durationSeconds == interaction.durationSeconds)
        #expect(secondOffers[0].itemInstanceID == secondInstance.id)
        #expect(firstInstance.definitionID == secondInstance.definitionID)
        #expect(firstInstance.id != secondInstance.id)
        #expect(firstInstance.position != secondInstance.position)
        #expect(catalog.definitions == [definition])
    }

    @Test func interactionDefinitionIDsAreNonemptyAndCodableAsStrings() throws {
        #expect(InteractionDefinitionID("") == nil)

        let definitionID = try #require(InteractionDefinitionID("wash-hands"))
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        #expect(
            try decoder.decode(InteractionDefinitionID.self, from: encoder.encode(definitionID))
                == definitionID
        )
    }

    @Test func identifierTypesRejectEmptyValuesAndEncodeAsStrings() throws {
        #expect(ItemDefinitionID("") == nil)
        #expect(ItemInstanceID("") == nil)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let definitionID = try #require(ItemDefinitionID("lamp"))
        let instanceID = try #require(ItemInstanceID("hall-lamp"))

        #expect(
            try decoder.decode(ItemDefinitionID.self, from: encoder.encode(definitionID))
                == definitionID
        )
        #expect(
            try decoder.decode(ItemInstanceID.self, from: encoder.encode(instanceID))
                == instanceID
        )
        #expect(
            try decoder.decode(ItemDefinitionID.self, from: Data("\"lamp\"".utf8))
                == definitionID
        )
        #expect(throws: DecodingError.self) {
            try decoder.decode(ItemInstanceID.self, from: Data("\"\"".utf8))
        }
    }

    @Test func catalogRejectsDuplicateDefinitionIDs() throws {
        let definitionID = try #require(ItemDefinitionID("chair"))
        let first = ItemDefinition(
            id: definitionID,
            identity: ItemIdentity(name: "Chair A", itemTypes: .chair),
            signals: []
        )
        let duplicate = ItemDefinition(
            id: definitionID,
            identity: ItemIdentity(name: "Chair B", itemTypes: .chair),
            signals: []
        )

        #expect(throws: ItemDefinitionCatalogError.self) {
            try ItemDefinitionCatalog(definitions: [first, duplicate])
        }
    }

    @Test func catalogRejectsDuplicateInteractionIDsWithinADefinition() throws {
        let definitionID = try #require(ItemDefinitionID("bookcase"))
        let interactionID = try #require(InteractionDefinitionID("read"))
        let interaction = try InteractionDefinition(
            id: interactionID,
            name: "Read",
            advertisedBenefits: [],
            motiveEffects: [],
            durationSeconds: 10
        )
        let definition = ItemDefinition(
            id: definitionID,
            identity: ItemIdentity(name: "Bookcase", itemTypes: .recreation),
            signals: [],
            interactions: [interaction, interaction]
        )

        #expect(throws: ItemDefinitionCatalogError.self) {
            try ItemDefinitionCatalog(definitions: [definition])
        }
    }

    @Test func interactionDefinitionsRejectInvalidContent() throws {
        let interactionID = try #require(InteractionDefinitionID("eat"))

        #expect(throws: InteractionDefinitionError.self) {
            try InteractionDefinition(
                id: interactionID,
                name: "",
                advertisedBenefits: [],
                motiveEffects: [],
                durationSeconds: 10
            )
        }
        #expect(throws: InteractionDefinitionError.self) {
            try InteractionDefinition(
                id: interactionID,
                name: "Eat",
                advertisedBenefits: [
                    MotiveBenefit(motiveType: .hunger, expectedStrengthPerSecond: .infinity)
                ],
                motiveEffects: [],
                durationSeconds: 10
            )
        }
        #expect(throws: InteractionDefinitionError.self) {
            try InteractionDefinition(
                id: interactionID,
                name: "Eat",
                advertisedBenefits: [],
                motiveEffects: [
                    MotiveSignal(motiveType: .hunger, strengthPerSecond: .nan)
                ],
                durationSeconds: 10
            )
        }
        for invalidDuration in [0, -1, .infinity, .nan] {
            #expect(throws: InteractionDefinitionError.invalidDuration) {
                try InteractionDefinition(
                    id: interactionID,
                    name: "Eat",
                    advertisedBenefits: [],
                    motiveEffects: [],
                    durationSeconds: invalidDuration
                )
            }
        }
    }

    @Test func catalogReportsMissingItemDefinitionWhenBuildingOffers() throws {
        let definitionID = try #require(ItemDefinitionID("missing"))
        let placedItem = PlacedItem(
            id: try #require(ItemInstanceID("item-1")),
            definitionID: definitionID,
            position: GridPosition(x: 0, y: 0)
        )
        let catalog = try ItemDefinitionCatalog(definitions: [])

        #expect(throws: ItemDefinitionCatalogError.self) {
            try catalog.interactionOffers(for: placedItem)
        }
    }

    @Test func eligibilityAllowsAvailableActorAndItemAtCapacityBoundary() throws {
        let offer = try makeOffer(requiredPosture: .sitting)
        let actor = InteractionActorSnapshot(posture: .sitting, isAvailable: true)
        let item = try makeItemSnapshot(isAvailable: true, capacity: 2, occupancy: 1)

        let result = InteractionEligibilitySystem.evaluate(offer, actor: actor, item: item)

        #expect(result.isEligible)
        #expect(result.reasons.isEmpty)
    }

    @Test func eligibilityReportsEveryUnmetRequirementInStableOrder() throws {
        let offer = try makeOffer(requiredPosture: .sitting)
        let actor = InteractionActorSnapshot(posture: .standing, isAvailable: false)
        let item = try makeItemSnapshot(isAvailable: false, capacity: 2, occupancy: 2)

        let result = InteractionEligibilitySystem.evaluate(offer, actor: actor, item: item)

        #expect(!result.isEligible)
        #expect(result.reasons == [
            .actorUnavailable,
            .postureMismatch(required: .sitting, actual: .standing),
            .itemUnavailable,
            .itemAtCapacity(capacity: 2, occupancy: 2),
        ])
    }

    @Test func missingEligibilitySnapshotsAreReported() throws {
        let offer = try makeOffer(requiredPosture: nil)

        let result = InteractionEligibilitySystem.evaluate(offer, actor: nil, item: nil)

        #expect(result.reasons == [.missingActorSnapshot, .missingItemSnapshot])
    }

    @Test func zeroCapacityAndOverCapacityItemsAreUnavailable() throws {
        let offer = try makeOffer(requiredPosture: nil)
        let actor = InteractionActorSnapshot(posture: .standing, isAvailable: true)
        let zeroCapacity = try makeItemSnapshot(isAvailable: true, capacity: 0, occupancy: 0)
        let overCapacity = try makeItemSnapshot(isAvailable: true, capacity: 1, occupancy: 2)

        #expect(InteractionEligibilitySystem.evaluate(
            offer,
            actor: actor,
            item: zeroCapacity
        ).reasons == [.itemAtCapacity(capacity: 0, occupancy: 0)])
        #expect(InteractionEligibilitySystem.evaluate(
            offer,
            actor: actor,
            item: overCapacity
        ).reasons == [.itemAtCapacity(capacity: 1, occupancy: 2)])
    }

    @Test func itemEligibilitySnapshotsRejectNegativeCounts() throws {
        let itemInstanceID = try #require(ItemInstanceID("eligibility-instance"))

        #expect(throws: InteractionItemSnapshotError.self) {
            try InteractionItemSnapshot(
                itemInstanceID: itemInstanceID,
                isAvailable: true,
                capacity: -1,
                occupancy: 0
            )
        }
        #expect(throws: InteractionItemSnapshotError.self) {
            try InteractionItemSnapshot(
                itemInstanceID: itemInstanceID,
                isAvailable: true,
                capacity: 1,
                occupancy: -1
            )
        }
    }

    @Test func eligibilityRejectsSnapshotForDifferentItemInstance() throws {
        let offer = try makeOffer(requiredPosture: nil)
        let actor = InteractionActorSnapshot(posture: .standing, isAvailable: true)
        let differentItemID = try #require(ItemInstanceID("different-instance"))
        let item = try InteractionItemSnapshot(
            itemInstanceID: differentItemID,
            isAvailable: true,
            capacity: 1,
            occupancy: 0
        )
        let expectedItemID = try #require(ItemInstanceID("eligibility-instance"))

        let result = InteractionEligibilitySystem.evaluate(offer, actor: actor, item: item)

        #expect(result.reasons == [
            .itemSnapshotMismatch(
                expected: expectedItemID,
                actual: differentItemID
            )
        ])
    }

    @Test func autonomyScoresAdvertisedBenefitsByCurrentMotiveUrgency() throws {
        let offer = try makeOffer(
            advertisedBenefits: [
                MotiveBenefit(motiveType: .hunger, expectedStrengthPerSecond: 2),
                MotiveBenefit(motiveType: .fun, expectedStrengthPerSecond: 4),
                MotiveBenefit(motiveType: .energy, expectedStrengthPerSecond: -6),
            ]
        )
        let motives = try makeMotiveLevels([
            .hunger: 0,
            .fun: 50,
            .energy: 100,
        ])

        let ranking = try AutonomyScoringSystem.rank([offer], for: motives)
        let scoredOffer = try #require(ranking.rankedOffers.first)

        #expect(scoredOffer.score == 4)
        #expect(scoredOffer.contributions.map(\.motiveType) == [.hunger, .energy, .fun])
        #expect(scoredOffer.contributions.map(\.motiveLevel) == [0, 100, 50])
        #expect(scoredOffer.contributions.map(\.urgency) == [1, 0, 0.5])
        #expect(scoredOffer.contributions.map(\.advertisedStrengthPerSecond) == [2, -6, 4])
        #expect(scoredOffer.contributions.map(\.score) == [2, 0, 2])
        #expect(ranking.selectedOffer == scoredOffer)
    }

    @Test func autonomyRankingUsesStableIDsForTiesAndRejectsNonPositiveChoices() throws {
        let laterID = try makeOffer(
            interactionID: "z-interaction",
            itemInstanceID: "a-item",
            advertisedBenefits: [
                MotiveBenefit(motiveType: .fun, expectedStrengthPerSecond: 2)
            ]
        )
        let earlierID = try makeOffer(
            interactionID: "a-interaction",
            itemInstanceID: "a-item",
            advertisedBenefits: [
                MotiveBenefit(motiveType: .hunger, expectedStrengthPerSecond: 2)
            ]
        )
        let higherItemID = try makeOffer(
            interactionID: "a-interaction",
            itemInstanceID: "z-item",
            advertisedBenefits: [
                MotiveBenefit(motiveType: .fun, expectedStrengthPerSecond: 2)
            ]
        )
        let zeroScore = try makeOffer(
            interactionID: "zero-score",
            advertisedBenefits: []
        )
        let negativeScore = try makeOffer(
            interactionID: "negative-score",
            advertisedBenefits: [
                MotiveBenefit(motiveType: .fun, expectedStrengthPerSecond: -2)
            ]
        )
        let motives = try makeMotiveLevels([.fun: 50, .hunger: 50])

        let ranking = try AutonomyScoringSystem.rank(
            [laterID, higherItemID, negativeScore, zeroScore, earlierID],
            for: motives
        )

        #expect(ranking.rankedOffers.map(\.offer) == [
            earlierID,
            laterID,
            higherItemID,
            zeroScore,
            negativeScore,
        ])
        #expect(ranking.selectedOffer?.offer == earlierID)

        let noUsefulOffers = try AutonomyScoringSystem.rank(
            [zeroScore, negativeScore],
            for: motives
        )
        #expect(noUsefulOffers.selectedOffer == nil)
        #expect(try AutonomyScoringSystem.rank([], for: motives).selectedOffer == nil)
    }

    @Test func autonomyScoringReportsOverflowInsteadOfReturningInvalidScores() throws {
        let offer = try makeOffer(
            advertisedBenefits: [
                MotiveBenefit(
                    motiveType: .hunger,
                    expectedStrengthPerSecond: .greatestFiniteMagnitude
                ),
                MotiveBenefit(
                    motiveType: .hunger,
                    expectedStrengthPerSecond: .greatestFiniteMagnitude
                ),
            ]
        )
        let motives = try makeMotiveLevels([.hunger: 0])

        #expect(throws: AutonomyScoringError.self) {
            try AutonomyScoringSystem.rank([offer], for: motives)
        }
    }

    @Test func actionProgressAppliesEffectsAndCompletesAtConfiguredDuration() throws {
        let offer = try makeOffer(
            motiveEffects: [
                MotiveSignal(motiveType: .hunger, strengthPerSecond: 2),
                MotiveSignal(motiveType: .energy, strengthPerSecond: -1),
            ],
            durationSeconds: 10
        )
        let initialMotives = try makeMotiveLevels([.hunger: 50, .energy: 50])
        let started = InteractionActionSystem.start(offer, initiatedBy: .playerCommand)

        #expect(started.status == .running)
        #expect(started.elapsedSeconds == 0)
        #expect(started.initiator == .playerCommand)

        let partialProgress = try InteractionActionSystem.advance(
            started,
            motives: initialMotives,
            bySeconds: 3
        )
        #expect(partialProgress.action.elapsedSeconds == 3)
        #expect(partialProgress.action.status == .running)
        #expect(partialProgress.motives.level(for: .hunger) == 56)
        #expect(partialProgress.motives.level(for: .energy) == 47)

        let completion = try InteractionActionSystem.advance(
            partialProgress.action,
            motives: partialProgress.motives,
            bySeconds: 20
        )
        #expect(completion.action.elapsedSeconds == 10)
        #expect(completion.action.status == .completed)
        #expect(completion.motives.level(for: .hunger) == 70)
        #expect(completion.motives.level(for: .energy) == 40)
        #expect(throws: InteractionActionError.actionIsNotRunning) {
            try InteractionActionSystem.advance(
                completion.action,
                motives: completion.motives,
                bySeconds: 1
            )
        }
    }

    @Test func actionInterruptionAndFailurePreservePriorProgressAndEffects() throws {
        let offer = try makeOffer(
            motiveEffects: [MotiveSignal(motiveType: .hunger, strengthPerSecond: 2)],
            durationSeconds: 10
        )
        let initialMotives = try makeMotiveLevels([.hunger: 50])
        let started = InteractionActionSystem.start(offer, initiatedBy: .autonomy)
        let progress = try InteractionActionSystem.advance(
            started,
            motives: initialMotives,
            bySeconds: 2
        )
        let interrupted = try InteractionActionSystem.interrupt(
            progress.action,
            because: .cancelled
        )

        #expect(progress.motives.level(for: .hunger) == 54)
        #expect(interrupted.elapsedSeconds == 2)
        #expect(interrupted.status == .interrupted(.cancelled))
        #expect(interrupted.initiator == .autonomy)
        #expect(throws: InteractionActionError.actionIsNotRunning) {
            try InteractionActionSystem.fail(interrupted, because: .executionFailed)
        }

        let failed = try InteractionActionSystem.fail(started, because: .itemUnavailable)
        #expect(failed.elapsedSeconds == 0)
        #expect(failed.status == .failed(.itemUnavailable))
    }

    @Test func actionProgressRejectsInvalidElapsedTime() throws {
        let offer = try makeOffer()
        let action = InteractionActionSystem.start(offer, initiatedBy: .playerCommand)
        let motives = try makeMotiveLevels()

        for invalidElapsedSeconds in [-1, .infinity, .nan] {
            #expect(throws: MotiveLevelsError.invalidElapsedSeconds) {
                try InteractionActionSystem.advance(
                    action,
                    motives: motives,
                    bySeconds: invalidElapsedSeconds
                )
            }
        }
    }

    private func makeOffer(
        interactionID: String = "eligibility-test",
        itemInstanceID: String = "eligibility-instance",
        advertisedBenefits: [MotiveBenefit] = [],
        motiveEffects: [MotiveSignal] = [],
        durationSeconds: Double = 10,
        requiredPosture: SimPosture? = nil
    ) throws -> InteractionOffer {
        let itemDefinitionID = try #require(ItemDefinitionID("eligibility-item"))
        let itemInstanceID = try #require(ItemInstanceID(itemInstanceID))
        let interactionID = try #require(InteractionDefinitionID(interactionID))
        let interaction = try InteractionDefinition(
            id: interactionID,
            name: "Use item",
            advertisedBenefits: advertisedBenefits,
            motiveEffects: motiveEffects,
            durationSeconds: durationSeconds,
            requirements: InteractionRequirements(requiredPosture: requiredPosture)
        )
        let definition = ItemDefinition(
            id: itemDefinitionID,
            identity: ItemIdentity(name: "Test item", itemTypes: .chair),
            signals: [],
            interactions: [interaction]
        )
        let catalog = try ItemDefinitionCatalog(definitions: [definition])
        let placedItem = PlacedItem(
            id: itemInstanceID,
            definitionID: itemDefinitionID,
            position: GridPosition(x: 0, y: 0)
        )

        return try #require(catalog.interactionOffers(for: placedItem).first)
    }

    private func makeMotiveLevels(
        _ overrides: [MotiveType: Double] = [:]
    ) throws -> MotiveLevels {
        var levels = Dictionary(
            uniqueKeysWithValues: MotiveType.allCases.map { ($0, 50.0) }
        )
        levels.merge(overrides) { _, override in override }
        return try MotiveLevels(levels: levels)
    }

    private func makeItemSnapshot(
        isAvailable: Bool,
        capacity: Int,
        occupancy: Int
    ) throws -> InteractionItemSnapshot {
        try InteractionItemSnapshot(
            itemInstanceID: #require(ItemInstanceID("eligibility-instance")),
            isAvailable: isAvailable,
            capacity: capacity,
            occupancy: occupancy
        )
    }
}
