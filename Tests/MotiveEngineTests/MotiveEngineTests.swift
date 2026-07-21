@testable import MotiveEngine
import Testing

let itemsJSON = """
[
    {
        "name": "Fridge",
        "itemType": "fridge",
        "signals": [
            { "motiveType": "hunger", "strengthPerSecond": 2.0 }
        ]
    },
    {
        "name": "Bed",
        "itemType": "bed",
        "signals": [
            { "motiveType": "energy", "strengthPerSecond": 1.5 }
        ]
    },
    {
        "name": "Shower",
        "itemType": "shower",
        "signals": [
            { "motiveType": "hygiene", "strengthPerSecond": 2.5 }
        ]
    },
    {
        "name": "Toilet",
        "itemType": "toilet",
        "signals": [
            { "motiveType": "bladder", "strengthPerSecond": 3.0 }
        ]
    },
    {
        "name": "Television",
        "itemType": "television",
        "signals": [
            { "motiveType": "fun", "strengthPerSecond": 1.0 },
            { "motiveType": "social", "strengthPerSecond": 0.3 }
        ]
    },
    {
        "name": "Telephone",
        "itemType": "telephone",
        "signals": [
            { "motiveType": "social", "strengthPerSecond": 2.0 }
        ]
    }
]
"""

@Test func example() {
    let tickDurationSeconds = 60.0

    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    // Swift Testing Documentation
    // https://swiftpackageindex.com/swiftlang/swift-testing/documentation
}
