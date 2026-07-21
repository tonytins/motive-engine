func clamped(_ value: Double, lowerBound: Double = 0, upperBound: Double = 100) -> Double {
    if value < lowerBound { return lowerBound }
    if value > upperBound { return upperBound }
    return value
}

func decayedMotiveLevels(
    from needLevels: [Needs: Double],
    decayRatesPerSecond: [Needs: Double],
    overSeconds elapsedSeconds: Double,
) -> [Needs: Double] {
    var updatedLevels = needLevels
    for needs in Needs.allCases {
        let decayRatePerSecond = decayRatesPerSecond[needs] ?? 0
        let currentLevel = needLevels[needs] ?? 100
        updatedLevels[needs] = clamped(
            currentLevel - decayRatePerSecond * elapsedSeconds,
        )
    }

    return updatedLevels
}
