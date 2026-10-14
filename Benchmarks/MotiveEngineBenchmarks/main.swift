import Foundation
import MotiveEngine

private let sampleCount = 30

private struct BenchmarkResult {
    let name: String
    let p95BudgetMilliseconds: Double
    let p50Milliseconds: Double
    let p95Milliseconds: Double
    let checksum: UInt64

    var exceedsBudget: Bool {
        p95Milliseconds > p95BudgetMilliseconds
    }
}

@main
private enum BenchmarkRunner {
    static func main() throws {
        let results = try [
            benchmarkMotives(),
            benchmarkEligibility(),
            benchmarkAutonomy(),
            benchmarkRobusta(),
        ]

        print("Configuration: release")
        print("Samples per workload: \(sampleCount), plus one warm-up")
        print("Workload | p50 (ms) | p95 (ms) | p95 budget (ms) | status | checksum")
        for result in results {
            print(
                "\(result.name) | \(format(result.p50Milliseconds)) | "
                    + "\(format(result.p95Milliseconds)) | "
                    + "\(format(result.p95BudgetMilliseconds)) | "
                    + "\(result.exceedsBudget ? "OVER BUDGET" : "PASS") | "
                    + "\(result.checksum)"
            )
        }

        let exceededBudgets = results.filter(\.exceedsBudget).map(\.name)
        guard exceededBudgets.isEmpty else {
            throw BenchmarkError.exceededBudgets(exceededBudgets)
        }
    }

    private static func benchmarkMotives() throws -> BenchmarkResult {
        let levels = try makeMotiveLevels()
        let rates = try MotiveDecayRates(
            ratesPerSecond: Dictionary(
                uniqueKeysWithValues: MotiveType.allCases.map { ($0, 0.01) }
            )
        )
        let snapshots = Array(repeating: levels, count: 10_000)

        return try measure(
            name: "Motives: 10,000 decays",
            p95BudgetMilliseconds: 50
        ) {
            var checksum: UInt64 = 0
            for snapshot in snapshots {
                let result = try MotiveSystem.decay(snapshot, using: rates, overSeconds: 1)
                checksum &+= UInt64(result.level(for: .hunger) * 1_000)
            }
            return checksum
        }
    }

    private static func benchmarkEligibility() throws -> BenchmarkResult {
        let offers = try makeOffers(count: 10_000)
        let actor = InteractionActorSnapshot(posture: .standing, isAvailable: true)
        let items = try offers.map {
            try InteractionItemSnapshot(
                itemInstanceID: $0.itemInstanceID,
                isAvailable: true,
                capacity: 1,
                occupancy: 0
            )
        }

        return try measure(
            name: "Eligibility: 10,000 evaluations",
            p95BudgetMilliseconds: 50
        ) {
            var eligibleCount: UInt64 = 0
            for (offer, item) in zip(offers, items) {
                if InteractionEligibilitySystem.evaluate(
                    offer,
                    actor: actor,
                    item: item
                ).isEligible {
                    eligibleCount &+= 1
                }
            }
            return eligibleCount
        }
    }

    private static func benchmarkAutonomy() throws -> BenchmarkResult {
        let offers = try makeOffers(count: 1_000)
        let motives = try makeMotiveLevels()

        return try measure(
            name: "Autonomy: rank 1,000 offers",
            p95BudgetMilliseconds: 25
        ) {
            let ranking = try AutonomyScoringSystem.rank(offers, for: motives)
            let scaledScore = UInt64((ranking.selectedOffer?.score ?? 0) * 1_000)
            return UInt64(ranking.rankedOffers.count) &+ scaledScore
        }
    }

    private static func benchmarkRobusta() throws -> BenchmarkResult {
        let source = (0 ..< 2_500)
            .map { "val item\($0) = \($0)" }
            .joined(separator: "\n")
        let tokenCount = try Lexer.tokenize(source).count
        guard tokenCount == 10_001 else {
            throw BenchmarkError.unexpectedTokenCount(tokenCount)
        }
        let frontend = RobustaFrontend()

        return try measure(
            name: "Robusta: tokenize and compile 10,001 tokens",
            p95BudgetMilliseconds: 100
        ) {
            let compiled = try RobustaCompiler.compile(source, using: frontend)
            return UInt64(compiled.count)
        }
    }

    private static func makeOffers(count: Int) throws -> [InteractionOffer] {
        let itemDefinitionID = try require(ItemDefinitionID("benchmark-item"))
        let interactionID = try require(InteractionDefinitionID("benchmark-use"))
        let interaction = try InteractionDefinition(
            id: interactionID,
            name: "Use benchmark item",
            advertisedBenefits: [
                MotiveBenefit(motiveType: .hunger, expectedStrengthPerSecond: 2),
                MotiveBenefit(motiveType: .fun, expectedStrengthPerSecond: 1),
            ],
            motiveEffects: [],
            durationSeconds: 30
        )
        let definition = try ItemDefinition(
            id: itemDefinitionID,
            identity: ItemIdentity(name: "Benchmark item", itemTypes: .recreation),
            signals: [],
            interactions: [interaction]
        )
        let catalog = try ItemDefinitionCatalog(definitions: [definition])

        return try (0 ..< count).map { index in
            let itemID = try require(ItemInstanceID("benchmark-instance-\(index)"))
            let item = PlacedItem(
                id: itemID,
                definitionID: itemDefinitionID,
                position: GridPosition(x: index, y: 0)
            )
            guard let offer = try catalog.interactionOffers(for: item).first else {
                throw BenchmarkError.missingInteractionOffer(index)
            }
            return offer
        }
    }

    private static func makeMotiveLevels() throws -> MotiveLevels {
        try MotiveLevels(
            levels: Dictionary(
                uniqueKeysWithValues: MotiveType.allCases.map { ($0, 50.0) }
            )
        )
    }

    private static func measure(
        name: String,
        p95BudgetMilliseconds: Double,
        operation: () throws -> UInt64
    ) throws -> BenchmarkResult {
        _ = try operation()
        var durations: [UInt64] = []
        var checksum: UInt64 = 0

        for _ in 0 ..< sampleCount {
            let start = DispatchTime.now().uptimeNanoseconds
            checksum &+= try operation()
            durations.append(DispatchTime.now().uptimeNanoseconds - start)
        }

        durations.sort()
        let p50 = durations[(sampleCount - 1) / 2]
        let p95 = durations[Int(ceil(Double(sampleCount) * 0.95)) - 1]

        return BenchmarkResult(
            name: name,
            p95BudgetMilliseconds: p95BudgetMilliseconds,
            p50Milliseconds: milliseconds(p50),
            p95Milliseconds: milliseconds(p95),
            checksum: checksum
        )
    }

    private static func milliseconds(_ nanoseconds: UInt64) -> Double {
        Double(nanoseconds) / 1_000_000
    }

    private static func format(_ milliseconds: Double) -> String {
        String(format: "%.3f", milliseconds)
    }

    private static func require<Value>(_ value: Value?) throws -> Value {
        guard let value else {
            throw BenchmarkError.invalidFixture
        }
        return value
    }
}

private enum BenchmarkError: Error {
    case invalidFixture
    case missingInteractionOffer(Int)
    case unexpectedTokenCount(Int)
    case exceededBudgets([String])
}

extension BenchmarkError: CustomStringConvertible {
    var description: String {
        switch self {
        case .invalidFixture:
            "Benchmark fixture is invalid."
        case let .missingInteractionOffer(index):
            "Benchmark offer \(index) is missing."
        case let .unexpectedTokenCount(count):
            "Expected 10,001 Robusta tokens, received \(count)."
        case let .exceededBudgets(names):
            "The following workloads exceeded their p95 budgets: \(names.joined(separator: ", "))."
        }
    }
}
