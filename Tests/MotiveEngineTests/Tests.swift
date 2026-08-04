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
    @Test()
    func itemCanBeAbmientAndSelected() {
        withKnownIssue {
            let stereo = Item(
                identity: ItemIdentity(
                    name: "Stereo",
                    itemTypes: [.ambient, .recreation]
                ),
                signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 2)]
            )
            
            #expect(stereo.isAmbient)
            #expect(stereo.isSelectable)
        }
    }
}

@Suite("Buff Tests")
struct BuffTests {
    @Test func bindToAmbientItemsOnly() async throws {
        let stereo = Item(
            identity: ItemIdentity(
                name: "Stereo",
                itemTypes: .ambient
            ),
            signals: [MotiveSignal(motiveType: .fun, strengthPerSecond: 2)]
        )
        
        #expect(BuffRegistry.buffs(for: stereo).contains {
                $0 is AmbientBuff
            })
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
