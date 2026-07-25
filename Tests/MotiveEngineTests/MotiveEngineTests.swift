@testable import MotiveEngine
import Foundation
import Testing

@Test func swafTest() async throws {
    let wantsFearsJSON = """
    {"want":{"be famous":["Outgoing","Ambitious"],"write a book":["Creative","Imaginative"],"travel the world":["Adventurous","Curious"],"have a family":["Nurturing","Family-Oriented"],"succeed in career":["Competitive","Ambitious"],"be respected":["Competitive","Nurturing"],"master a skill":["Ambitious","Independent"],"make new friends":["Outgoing","Social"],"explore the unknown":["Curious","Imaginative"],"build something lasting":["Creative","Family-Oriented"],"live off the grid":["Independent","Adventurous"],"find true love":["Nurturing","Social"],"start a business":["Ambitious","Creative"],"learn everything":["Outgoing","Curious"]},"fear":{"failure":["Shy","Insecure"],"heights":["Anxious","Risk-Averse"],"loneliness":["Social","Lonely"],"commitment":["Avoidant","Independent"],"not being liked":["Nervous","Shy"],"rejection":["Insecure","Nervous"],"being forgotten":["Lonely","Insecure"],"losing control":["Anxious","Avoidant"],"change":["Risk-Averse","Avoidant"],"intimacy":["Avoidant","Nervous"],"judgment":["Shy","Anxious"],"abandonment":["Lonely","Avoidant"],"isolation":["Independent","Lonely"],"conflict":["Competitive","Nervous"]}}
    """

    let wantsFearsData = Data(wantsFearsJSON.utf8)
    let catalog = try WantFearCatalog(jsonData: wantsFearsData)

    let sim = await Sim(
        name: "Tom",
        personalityTraits: [.eccentric, .geek, .avantGarde],
        catalog: catalog,
    )

    let state = await sim.state
    let wants = await sim.activeWants
    let fears = await sim.activeFears
}
