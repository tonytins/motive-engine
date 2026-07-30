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

extension Set where Element == ItemType {
    var isBlockingByDefualt: Bool {
        contains{ $0.isBlockingByDefault }
    }
}


extension Sequence where Element == ItemType {
    var isBlockingByDefualt: Bool {
        contains{ $0.isBlockingByDefault }
    }
    
    var grantsSittingPosture: Bool {
        contains{ $0.grantsSittingPosture }
    }
    
    func delegatesTo(posture: SimPosture) -> Set<ItemType> {
        reduce(into: Set<ItemType>()) { $0.formUnion($1.delegatesTo(posture: posture)) }
    }
    
    func toSet() -> Set<ItemType> { Set(self) }
}
