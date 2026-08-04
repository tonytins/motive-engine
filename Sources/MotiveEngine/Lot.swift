
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

extension ItemFunction {
    var arrivalRadius: Int {
        self == .sim ? 1 : 0
    }
}

struct RadarPing: Sendable {
    let name: String
    let function: ItemFunction
    let isBlocking: Bool
    let position: GridPosition
    let distance: Int
}

struct PlacedItem: Sendable {
    let item: Item
    let position: GridPosition
}

struct LotSnapshot: Sendable {
    struct Occupant: Sendable {
        let name: String
        let position: GridPosition
        let function: ItemFunction
        let modifiers: Set<ItemModifier>
        let isSim: Bool
        let isAsleep: Bool
    }

    let size: GridSize
    let occupants: [Occupant]
}

enum Pathfinding {
    public static func nextStep(from origin: GridPosition,
                  toward destination: GridPosition,
                  blocked: Set<GridPosition>,
                  bounds: GridSize) -> GridPosition {
        guard origin != destination else {
            return origin
        }
        
        var cameFrom: [GridPosition: GridPosition] = [:]
        var frontier = [origin]
        var visited: Set<GridPosition> = [origin]
        
        while !frontier.isEmpty {
            var nextFrontier: [GridPosition] = []
            for tile in frontier {
                if tile == destination {
                    return firstStep(from: origin,
                              to: destination,
                              cameFrom: cameFrom)
                }
                for neighbor in tile.orthogonalNeighbors {
                    guard bounds
                        .contains(neighbor), !visited
                        .contains(neighbor) else {
                        continue
                    }
                    
                    guard neighbor == destination ||
                            !blocked.contains(neighbor) else { continue }
                    visited.insert(neighbor)
                    cameFrom[neighbor] = tile
                    nextFrontier.append(neighbor)
                }
               
            }
            
            frontier = nextFrontier
        }
        
        return origin
    }
    
    static func firstStep(
        from origin: GridPosition,
        to destination: GridPosition,
        cameFrom: [GridPosition: GridPosition]
    ) -> GridPosition {
        var step = destination
        while let previous = cameFrom[step], previous != origin {
            step = previous
        }
        return step
    }
}
