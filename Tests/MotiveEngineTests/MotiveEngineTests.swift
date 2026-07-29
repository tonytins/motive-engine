import Foundation
@testable import MotiveEngine
import Testing

@Test func `swaf test`() async throws {
    let wantsFearsJSON = """
    {
    "want":{},
    "fear":{}
    }
    """

    let wantsFearsData = Data(wantsFearsJSON.utf8)
    let catalog = try WantFearCatalog(jsonData: wantsFearsData)

    let sim = await Sim(
        name: "Tom",
        personalityTraits: [.eccentric, .geek, .avantGarde],
        catalog: catalog,
        activeWantCount: 2,
        activeFearCount: 1,
    )

    let state = await sim.state
    let wants = await sim.activeWants
    let fears = await sim.activeFears
}
