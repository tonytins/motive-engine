internal extension Double {
    func clamped(_ value: Double, lowerBound: Double = 0, upperBound: Double = 100) -> Double {
        if value < lowerBound { return lowerBound }
        if value > upperBound { return upperBound }
        return value
    }
    
    func clamped(to range: ClosedRange<Double>) -> Double {
            min(max(self, range.lowerBound), range.upperBound)
        }
}
