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
            ]
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
            motiveEffects: []
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
                motiveEffects: []
            )
        }
        #expect(throws: InteractionDefinitionError.self) {
            try InteractionDefinition(
                id: interactionID,
                name: "Eat",
                advertisedBenefits: [
                    MotiveBenefit(motiveType: .hunger, expectedStrengthPerSecond: .infinity)
                ],
                motiveEffects: []
            )
        }
        #expect(throws: InteractionDefinitionError.self) {
            try InteractionDefinition(
                id: interactionID,
                name: "Eat",
                advertisedBenefits: [],
                motiveEffects: [
                    MotiveSignal(motiveType: .hunger, strengthPerSecond: .nan)
                ]
            )
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
}
