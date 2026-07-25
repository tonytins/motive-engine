extension Double {
    static func clamped(_ value: Double, lowerBound: Double = 0, upperBound: Double = 100) -> Double {
        if value < lowerBound { return lowerBound }
        if value > upperBound { return upperBound }
        return value
    }
}
