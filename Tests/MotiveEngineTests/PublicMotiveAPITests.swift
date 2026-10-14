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
        let definition = ItemDefinition(
            id: definitionID,
            identity: ItemIdentity(name: "Small Chair", itemTypes: .chair),
            signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 0.5)]
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
        #expect(firstInstance.definitionID == secondInstance.definitionID)
        #expect(firstInstance.id != secondInstance.id)
        #expect(firstInstance.position != secondInstance.position)
        #expect(catalog.definitions == [definition])
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
}
