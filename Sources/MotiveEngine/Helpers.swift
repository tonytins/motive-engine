extension Double {
    func clamped(_ value: Double, lowerBound: Double = 0, upperBound: Double = 100) -> Double {
        if value < lowerBound { return lowerBound }
        if value > upperBound { return upperBound }
        return value
    }

    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Set<ItemModifer> {
    var isBlockingByDefualt: Bool {
        contains { $0.isBlockingByDefault }
    }
}

extension Sequence<ItemModifer> {
    var isBlockingByDefualt: Bool {
        contains { $0.isBlockingByDefault }
    }

    var grantsSittingPosture: Bool {
        contains { $0.grantsSittingPosture }
    }

    func delegatesTo(posture: SimPosture) -> Set<ItemModifer> {
        reduce(into: Set<ItemModifer>()) { $0.formUnion($1.delegatesTo(posture: posture)) }
    }

    func toSet() -> Set<ItemModifer> {
        Set(self)
    }
}
