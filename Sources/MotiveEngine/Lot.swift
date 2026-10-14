
import Foundation

public struct GridPosition: Hashable, Sendable {
    /// The horizontal coordinate.
    public let x: Int

    /// The vertical coordinate.
    public let y: Int

    /// Creates a position using integer grid coordinates.
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// The four directly adjacent positions.
    public var orthogonalNeighbors: [GridPosition] {
        [
            GridPosition(x: x, y: y - 1),
            GridPosition(x: x, y: y + 1),
            GridPosition(x: x - 1, y: y),
            GridPosition(x: x + 1, y: y),
        ]
    }

    /// Returns the Manhattan distance to another grid position.
    public func distance(to other: GridPosition) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }
}

/// The width and height of a rectangular grid.
public struct GridSize: Equatable, Sendable {
    /// The number of columns.
    public let width: Int

    /// The number of rows.
    public let height: Int

    /// Creates grid bounds using integer dimensions.
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// Whether a position is inside these bounds.
    public func contains(_ position: GridPosition) -> Bool {
        position.x >= 0 && position.x < width
            && position.y >= 0 && position.y < height
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

/// Mutable placement data for one item instance on a lot.
public struct PlacedItem: Equatable, Sendable {
    /// The stable identity of this placed instance.
    public let id: ItemInstanceID

    /// The reusable content this instance uses.
    public let definitionID: ItemDefinitionID

    /// The instance's current grid position.
    public var position: GridPosition

    /// Creates an item instance referencing reusable content.
    public init(id: ItemInstanceID, definitionID: ItemDefinitionID, position: GridPosition) {
        self.id = id
        self.definitionID = definitionID
        self.position = position
    }
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
