import Foundation
@testable import MotiveEngine
import Testing

@Suite("Item Tests")
struct ItemTests {
    @Test()
    func chairDelegation() async throws {
        
        #expect(
            ItemModifer.chair.delegatesTo(posture: .sitting) == [.recreation, .sim]
        )
        
    }
    
    @Test func fridgeDelegation() async throws {
        
        #expect(
            ItemModifer.appliance
                .delegatesTo(posture: .standing) == [.sim]
        )
        
        #expect(
            ItemModifer.appliance
                .delegatesTo(posture: .sitting)
                .isEmpty
        )
    }
    
    @Test func toiletSitsButDelegatesNothings() {
        
        #expect(ItemModifer.toilet.grantsSittingPosture)
        
        #expect(ItemModifer.toilet
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
