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
}
