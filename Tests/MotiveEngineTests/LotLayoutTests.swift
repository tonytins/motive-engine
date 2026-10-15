import Foundation
import MotiveEngine
import Testing

private let allMotives = #"{"hunger": 25, "energy": 70, "hygiene": 80, "bladder": 60, "social": 55, "fun": 40}"#

/// A layout with the given item and Sim JSON entries.
private func layoutJSON(width: Int = 4, height: Int = 3, household: String? = "newbie", items: [String], sims: [String]) -> Data {
    let householdField = household.map { #""household": "\#($0)", "# } ?? ""
    return Data(#"""
    {"width": \#(width), "height": \#(height), \#(householdField)
     "items": [\#(items.joined(separator: ","))], "sims": [\#(sims.joined(separator: ","))]}
    """#.utf8)
}

private func item(_ id: String, _ definition: String, x: Int, y: Int = 0) -> String {
    #"{"id": "\#(id)", "definition": "\#(definition)", "x": \#(x), "y": \#(y)}"#
}

private func sim(_ id: String, name: String? = nil, x: Int, y: Int = 2, motives: String = allMotives) -> String {
    #"{"id": "\#(id)", "name": "\#(name ?? id.capitalized)", "x": \#(x), "y": \#(y), "motives": \#(motives)}"#
}

/// A catalog with `base:fridge` and `base:television`.
private func makeCatalog() throws -> ItemDefinitionCatalog {
    try ItemDefinitionCatalog(definitions: ["base:fridge", "base:television"].map {
        try ItemDefinition(
            id: #require(ItemDefinitionID($0)),
            identity: ItemIdentity(name: $0, itemTypes: .appliance),
            signals: []
        )
    })
}

private func lotID() throws -> LotID {
    try #require(LotID("home"))
}

@Suite("Lot layouts")
struct LotLayoutTests {
    @Test func layoutsDecodeAndBuildAValidatedWorld() throws {
        let layout = try LotLayout(jsonData: layoutJSON(
            items: [item("fridge", "base:fridge", x: 0), item("tv", "base:television", x: 3)],
            sims: [sim("bob", x: 1), sim("betty", x: 2)]
        ))

        let world = try layout.makeState(lotID: lotID(), catalog: makeCatalog())

        let bobID = try #require(SimID("bob"))
        let householdID = try #require(HouseholdID("newbie"))
        let bob = try #require(world.state.sim(for: bobID))
        let household = try #require(world.state.household(for: householdID))
        #expect(layout.sims.map(\.name) == ["Bob", "Betty"])
        #expect(bob.position == GridPosition(x: 1, y: 2))
        #expect(bob.currentLotID == (try lotID()))
        #expect(bob.posture == .standing)
        #expect(bob.motives.level(for: .hunger) == 25)
        #expect(household.memberIDs.map(\.rawValue) == ["bob", "betty"])
        #expect(world.state.lot(for: try lotID())?.placedItems.map(\.id.rawValue) == ["fridge", "tv"])
        #expect(world.skippedItems.isEmpty)
    }

    @Test func layoutsWithoutAHouseholdBuildNone() throws {
        let layout = try LotLayout(jsonData: layoutJSON(household: nil, items: [], sims: [sim("bob", x: 1)]))

        let world = try layout.makeState(lotID: lotID(), catalog: makeCatalog())

        #expect(world.state.households.isEmpty)
    }

    @Test func missingContentIsRejectedUnlessTheGameSkipsIt() throws {
        let layout = try LotLayout(jsonData: layoutJSON(
            items: [item("fridge", "base:fridge", x: 0), item("radio", "mod:radio", x: 1)],
            sims: []
        ))

        let radio = try #require(ItemDefinitionID("mod:radio"))
        #expect(throws: LotLayoutError.missingDefinition(radio)) {
            try layout.makeState(lotID: lotID(), catalog: makeCatalog())
        }
        let world = try layout.makeState(lotID: lotID(), catalog: makeCatalog(), missingContent: .skip)
        #expect(world.skippedItems.map(\.id.rawValue) == ["radio"])
        #expect(world.state.lot(for: try lotID())?.placedItems.map(\.id.rawValue) == ["fridge"])
    }

    @Test(arguments: [
        (layoutJSON(width: 0, items: [], sims: []), LotLayoutError.invalidSize),
        (layoutJSON(items: [item("a", "base:fridge", x: 0), item("a", "base:fridge", x: 1)], sims: []),
         LotLayoutError.duplicateItem(ItemInstanceID("a")!)),
        (layoutJSON(items: [], sims: [sim("bob", x: 0), sim("bob", x: 1)]), LotLayoutError.duplicateSim(SimID("bob")!)),
        (layoutJSON(items: [], sims: [sim("bob", name: "", x: 0)]), LotLayoutError.emptyName(SimID("bob")!)),
        (layoutJSON(items: [], sims: [sim("bob", x: 0, motives: #"{"hunger": 1, "thirst": 2}"#)]),
         LotLayoutError.unknownMotive(simID: SimID("bob")!, motive: "thirst")),
    ])
    func invalidLayoutsAreRejected(json: Data, expectedError: LotLayoutError) {
        #expect(throws: expectedError) {
            try LotLayout(jsonData: json)
        }
    }

    @Test func incompleteMotivesAndOutOfBoundsPositionsAreRejected() throws {
        #expect(throws: MotiveLevelsError.self) {
            try LotLayout(jsonData: layoutJSON(items: [], sims: [sim("bob", x: 0, motives: #"{"hunger": 50}"#)]))
        }

        let outside = try LotLayout(jsonData: layoutJSON(items: [item("fridge", "base:fridge", x: 9)], sims: []))
        #expect(throws: LotStateError.self) {
            try outside.makeState(lotID: lotID(), catalog: makeCatalog())
        }
        let overlapping = try LotLayout(jsonData: layoutJSON(items: [], sims: [sim("bob", x: 1), sim("betty", x: 1)]))
        #expect(throws: SimulationStateError.self) {
            try overlapping.makeState(lotID: lotID(), catalog: makeCatalog())
        }
    }

    @Test func schemaExampleDecodesAndBuilds() throws {
        let schemaURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../schema/lot.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL)) as? [String: Any]
        let example = try #require((schema?["examples"] as? [Any])?.first)

        let layout = try LotLayout(jsonData: JSONSerialization.data(withJSONObject: example))
        let world = try layout.makeState(lotID: lotID(), catalog: makeCatalog())

        #expect(world.state.sims.count == 1)
        #expect(world.state.lot(for: try lotID())?.placedItems.count == 2)
    }
}
