import Foundation
@testable import MotiveEngine
import Testing

@Suite("Item Tests")
struct ItemTests {
    @Test()
    func chairDelegation() async throws {
        
        #expect(
            ItemModifier.chair.delegatesTo(posture: .sitting) == [.recreation, .sim]
        )
        
    }
    
    @Test func fridgeDelegation() async throws {
        
        #expect(
            ItemModifier.appliance
                .delegatesTo(posture: .standing) == [.sim]
        )
        
        #expect(
            ItemModifier.appliance
                .delegatesTo(posture: .sitting)
                .isEmpty
        )
    }
    
    @Test func toiletSitsButDelegatesNothings() {
        
        #expect(ItemModifier.toilet.grantsSittingPosture)
        
        #expect(ItemModifier.toilet
            .delegatesTo(posture: .sitting)
            .isEmpty
        )
        
    }
}

@Suite("Multi-role Items")
struct MultiRoleItemsTests {
    @Test
    func itemCanBeAmbientAndSelected() {
        let stereo = Item(
            identity: ItemIdentity(
                name: "Stereo",
                itemTypes: [.ambient, .recreation]
            ),
            signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 2)]
        )

        #expect(stereo.isAmbient)
        #expect(stereo.isSelectable)
        #expect(stereo.buffSignals == stereo.signals)
    }
}

@Suite("Grid Geometry")
struct GridGeometryTests {
    @Test func boundsUseWidthForXAndHeightForY() {
        let bounds = GridSize(width: 3, height: 2)

        #expect(bounds.contains(GridPosition(x: 2, y: 1)))
        #expect(!bounds.contains(GridPosition(x: 3, y: 1)))
        #expect(!bounds.contains(GridPosition(x: 2, y: 2)))
    }

    @Test func boundsRejectNegativeCoordinatesAndEmptyDimensions() {
        #expect(!GridSize(width: 3, height: 2).contains(GridPosition(x: -1, y: 0)))
        #expect(!GridSize(width: 3, height: 2).contains(GridPosition(x: 0, y: -1)))
        #expect(!GridSize(width: 0, height: 2).contains(GridPosition(x: 0, y: 0)))
    }
}

@Suite("Household Roster")
struct HouseholdRosterTests {
    @Test func sleepAndWakeEventsUpdateSleepingNames() {
        var roster = HouseholdRoster()

        roster.receive(.fallAsleep, from: "Alex")
        #expect(roster.isSleeping(simNamed: "Alex"))
        #expect(roster.lastBroadcast["Alex"] == .fallAsleep)

        roster.receive(.wokeUp, from: "Alex")
        #expect(!roster.isSleeping(simNamed: "Alex"))
        #expect(roster.lastBroadcast["Alex"] == .wokeUp)
    }

    @Test func reachableSimsExcludesSelfAndSleepingSims() {
        var roster = HouseholdRoster()
        roster.receive(.fallAsleep, from: "Blair")

        #expect(roster.reachableSims(
            excluding: "Alex",
            among: ["Alex", "Blair", "Casey"]
        ) == ["Casey"])
    }
}

@Suite("Item Coding")
struct ItemCodingTests {
    @Test func decodesRawMotiveStrengthAndDefaultBlocking() throws {
        let json = #"{"name":"Fridge","item":"appliance","motives":[{"hunger":50}]}"#
        let item = try JSONDecoder().decode(Item.self, from: Data(json.utf8))

        #expect(item.identity.name == "Fridge")
        #expect(item.identity.isBlocking)
        #expect(item.signals == [MotiveSignal(motiveType: .hunger, strengthPerSecond: 2)])
    }

    @Test func explicitBlockingOverridesTheDefault() throws {
        let json = #"{"name":"Fridge","item":"appliance","blocking":false,"motives":[{"hunger":50}]}"#
        let item = try JSONDecoder().decode(Item.self, from: Data(json.utf8))

        #expect(!item.identity.isBlocking)
    }

    @Test func encodingRoundTripsItemValues() throws {
        let item = Item(
            identity: ItemIdentity(name: "Stereo", itemTypes: [.ambient, .recreation]),
            signals: [
                MotiveSignal(motiveType: .fun, strengthPerSecond: 2),
                MotiveSignal(motiveType: .social, strengthPerSecond: 0.5),
            ]
        )
        let encoded = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(Item.self, from: encoded)

        #expect(decoded == item)
    }
}

@Suite("Motive State")
struct MotiveStateTests {
    @Test func requiresEveryMotiveAndClampsFiniteLevels() throws {
        var levels = Dictionary(
            uniqueKeysWithValues: MotiveType.allCases.map { ($0, 50.0) }
        )
        levels[.energy] = -20
        levels[.fun] = 140

        let motives = try MotiveLevels(levels: levels)

        #expect(motives.level(for: .energy) == MotiveLevels.minimumValue)
        #expect(motives.level(for: .fun) == MotiveLevels.maximumValue)
        #expect(motives.level(for: .hunger) == 50)
    }

    @Test func rejectsMissingAndNonFiniteMotiveLevels() {
        #expect(throws: MotiveLevelsError.self) {
            try MotiveLevels(levels: [.hunger: 50])
        }

        var levels = Dictionary(
            uniqueKeysWithValues: MotiveType.allCases.map { ($0, 50.0) }
        )
        levels[.hygiene] = .nan

        #expect(throws: MotiveLevelsError.self) {
            try MotiveLevels(levels: levels)
        }
    }

    @Test func requiresFiniteNonnegativeDecayRateForEveryMotive() {
        #expect(throws: MotiveLevelsError.self) {
            try MotiveDecayRates(ratesPerSecond: [.hunger: 1])
        }

        var rates = Dictionary(
            uniqueKeysWithValues: MotiveType.allCases.map { ($0, 0.0) }
        )
        rates[.bladder] = -1

        #expect(throws: MotiveLevelsError.self) {
            try MotiveDecayRates(ratesPerSecond: rates)
        }
    }

    @Test func decayAndFulfillmentReturnClampedNewValues() throws {
        let levels = try makeMotiveLevels(defaultingTo: 70, overrides: [
            .hunger: 45,
            .energy: 20,
            .fun: 10,
        ])
        let rates = try makeDecayRates(defaultingTo: 0.25, overrides: [
            .hunger: 0.5,
            .energy: 2,
        ])

        let decayed = try MotiveSystem.decay(levels, using: rates, overSeconds: 10)
        #expect(levels.level(for: .energy) == 20)
        #expect(decayed.level(for: .energy) == 0)
        #expect(decayed.level(for: .hunger) == 40)
        #expect(decayed.level(for: .social) == 67.5)

        let fulfilled = try MotiveSystem.fulfill(
            decayed,
            with: [
                MotiveSignal(motiveType: .hunger, strengthPerSecond: 4),
                MotiveSignal(motiveType: .fun, strengthPerSecond: -2),
            ],
            overSeconds: 10
        )
        #expect(fulfilled.level(for: .hunger) == 80)
        #expect(fulfilled.level(for: .fun) == 0)
        #expect(decayed.level(for: .hunger) == 40)
    }

    @Test func lowestMotiveUsesStableCaseOrderForTies() throws {
        let levels = try makeMotiveLevels(defaultingTo: 30, overrides: [
            .energy: 10,
            .hygiene: 10,
        ])

        #expect(levels.lowest.motiveType == .energy)
        #expect(levels.lowest.level == 10)
    }

    @Test func rejectsInvalidElapsedTimeAndNonFiniteSignals() throws {
        let levels = try makeMotiveLevels(defaultingTo: 50)
        let rates = try makeDecayRates(defaultingTo: 1)

        #expect(throws: MotiveLevelsError.self) {
            try MotiveSystem.decay(levels, using: rates, overSeconds: -.infinity)
        }
        #expect(throws: MotiveLevelsError.self) {
            try MotiveSystem.fulfill(
                levels,
                with: [MotiveSignal(motiveType: .hunger, strengthPerSecond: .nan)],
                overSeconds: 1
            )
        }
    }

    @Test func finiteExtremeRatesAndSignalsSaturateAtBounds() throws {
        let levels = try makeMotiveLevels(defaultingTo: 50)
        let rates = try makeDecayRates(defaultingTo: 1e308)

        let decayed = try MotiveSystem.decay(levels, using: rates, overSeconds: 2)
        let fulfilled = try MotiveSystem.fulfill(
            levels,
            with: [MotiveSignal(motiveType: .hunger, strengthPerSecond: 1e308)],
            overSeconds: 2
        )

        #expect(decayed.level(for: .hunger) == MotiveLevels.minimumValue)
        #expect(fulfilled.level(for: .hunger) == MotiveLevels.maximumValue)
    }

    private func makeMotiveLevels(
        defaultingTo value: Double,
        overrides: [MotiveType: Double] = [:]
    ) throws -> MotiveLevels {
        var levels = Dictionary(
            uniqueKeysWithValues: MotiveType.allCases.map { ($0, value) }
        )
        levels.merge(overrides) { _, override in override }
        return try MotiveLevels(levels: levels)
    }

    private func makeDecayRates(
        defaultingTo value: Double,
        overrides: [MotiveType: Double] = [:]
    ) throws -> MotiveDecayRates {
        var rates = Dictionary(
            uniqueKeysWithValues: MotiveType.allCases.map { ($0, value) }
        )
        rates.merge(overrides) { _, override in override }
        return try MotiveDecayRates(ratesPerSecond: rates)
    }
}


@Suite("Pathfinding")
struct PathfindingTests {
    let origin = GridPosition(x: 0, y: 0)
    let destination = GridPosition(x: 1, y: 0)
    
    // The Grid
    // A digital frontier
    let theGrid = GridSize(width: 5, height: 5)
    
    @Test func StepsDirectlyAdjacentDestiation() {
        let next = Pathfinding.nextStep(
            from: origin,
            toward: destination,
            blocked: [],
            bounds: theGrid
        )
        
        #expect(next == GridPosition(x: 1, y: 0))
    }
    
    @Test func routeAroundBlockedTile() {
        let blocked: Set<GridPosition> = [destination]
        let next = Pathfinding.nextStep(
            from: origin,
            toward: GridPosition(x: 2, y: 0),
            blocked: blocked,
            bounds: theGrid
        )
        
        #expect(next != destination)
        #expect(origin.distance(to: next) == 1)
    }
    
    // When the character needs to use the object
    @Test func canStepOntoBlockedDestiation() {
        let next = Pathfinding.nextStep(
            from: origin,
            toward: destination,
            blocked: [destination],
            bounds: theGrid
        )
        
        #expect(next == destination)
    }
    
    @Test func stayPutWhenAlreadyThere() {
        let position = GridPosition(x: 2, y: 2)
        let next = Pathfinding.nextStep(
            from: position,
            toward: position,
            blocked: [],
            bounds: theGrid
        )
        
        #expect(next == position)
    }
    
    @Test func staysPutWhenNoRouteExists() {
        let blocked: Set<GridPosition> = [
            destination,
            GridPosition(x: 0, y: 1)
        ]
        let next = Pathfinding.nextStep(
            from: origin,
            toward: GridPosition(x: 1, y: 1),
            blocked: blocked,
            bounds: GridSize(width: 2, height: 2)
        )
        
        #expect(next == origin)
    }
}
