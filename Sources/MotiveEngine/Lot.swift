
import Foundation

struct GridPosition: Hashable {
    let x: Int
    let y: Int

    var orthogonalNeighbors: [GridPosition] {
        [
            GridPosition(x: x, y: y - 1),
            GridPosition(x: x, y: y + 1),
            GridPosition(x: x - 1, y: y),
            GridPosition(x: x + 1, y: y),
        ]
    }

    func distance(to other: GridPosition) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }
}

struct GridSize {
    let width: Int
    let height: Int

    func contains(_ position: GridPosition) -> Bool {
        (0 ..< width).contains(position.y) && (0 ..< height)
            .contains(position.x)
    }
}
