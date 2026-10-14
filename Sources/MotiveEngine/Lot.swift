
import Foundation

/// A tile on a lot's grid.
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

/// The next step toward an interaction item's usable approach area.
public enum InteractionRouteStep: Equatable, Sendable {
    /// The Sim already occupies a free tile next to the item.
    case arrived

    /// The Sim should move to this adjacent tile.
    case move(to: GridPosition)

    /// No free route to an approach tile exists.
    case unreachable
}

/// Deterministic grid routing to a free orthogonally adjacent item tile.
public enum InteractionRoutingSystem {
    /// Returns the next step toward a free tile next to the target item.
    ///
    /// Blocking items and occupied Sim positions cannot be traversed or used
    /// as approach tiles. Ties follow the stable neighbor order exposed by
    /// `GridPosition.orthogonalNeighbors`.
    public static func nextStep(
        from origin: GridPosition,
        towardItemAt itemPosition: GridPosition,
        blocked: Set<GridPosition>,
        occupied: Set<GridPosition>,
        bounds: GridSize
    ) -> InteractionRouteStep {
        let approachPositions = Set(itemPosition.orthogonalNeighbors.filter {
            bounds.contains($0) && !blocked.contains($0) && !occupied.contains($0)
        })
        guard !approachPositions.isEmpty else {
            return .unreachable
        }
        guard !approachPositions.contains(origin) else {
            return .arrived
        }

        var cameFrom: [GridPosition: GridPosition] = [:]
        var frontier = [origin]
        var visited: Set<GridPosition> = [origin]

        while !frontier.isEmpty {
            var nextFrontier: [GridPosition] = []
            for position in frontier {
                for neighbor in position.orthogonalNeighbors {
                    guard bounds.contains(neighbor),
                          !blocked.contains(neighbor),
                          !occupied.contains(neighbor),
                          visited.insert(neighbor).inserted
                    else {
                        continue
                    }

                    cameFrom[neighbor] = position
                    guard !approachPositions.contains(neighbor) else {
                        return .move(
                            to: Pathfinding.firstStep(
                                from: origin,
                                to: neighbor,
                                cameFrom: cameFrom
                            )
                        )
                    }
                    nextFrontier.append(neighbor)
                }
            }
            frontier = nextFrontier
        }

        return .unreachable
    }
}

enum Pathfinding {
    /// Returns the first step on a shortest path, or `origin` when no path exists.
    ///
    /// The destination may be blocked; every other tile on the path must not be.
    static func nextStep(
        from origin: GridPosition,
        toward destination: GridPosition,
        blocked: Set<GridPosition>,
        bounds: GridSize
    ) -> GridPosition {
        guard origin != destination else {
            return origin
        }

        var cameFrom: [GridPosition: GridPosition] = [:]
        var frontier = [origin]
        var visited: Set<GridPosition> = [origin]

        while !frontier.isEmpty {
            var nextFrontier: [GridPosition] = []
            for tile in frontier {
                guard tile != destination else {
                    return firstStep(from: origin, to: destination, cameFrom: cameFrom)
                }
                for neighbor in tile.orthogonalNeighbors
                    where bounds.contains(neighbor)
                    && !visited.contains(neighbor)
                    && (neighbor == destination || !blocked.contains(neighbor))
                {
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
