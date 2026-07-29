import Foundation
@testable import MotiveEngine
import Testing

@Suite("Item Tests")
struct ItemTests {
    @Test func chairDelegation() async throws {
        
        #expect(
            ItemType.chair.delegatesTo(posture: .sitting) == [.recreation, .sim]
        )
        
    }
    
    @Test func fridgeDelegation() async throws {
        
        #expect(
            ItemType.fridge
                .delegatesTo(posture: .standing) == [.sim]
        )
        
        #expect(
            ItemType.fridge
                .delegatesTo(posture: .sitting)
                .isEmpty
        )
    }
    
    @Test func toiletSitsButDelegatesNothings() {
        
        #expect(ItemType.toilet.grantsSittingPosture)
        
        #expect(ItemType.toilet
            .delegatesTo(posture: .sitting)
            .isEmpty
        )
        
    }
}
