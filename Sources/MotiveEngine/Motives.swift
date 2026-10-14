import Foundation

/// A need tracked by the simulation.
public enum MotiveType: String, CaseIterable, Hashable, Codable, Sendable {
    case hunger
    case energy
    case hygiene
    case bladder
    case social
    case fun
}

/// A per-second change offered by an interaction or effect.
///
/// Positive strengths fulfill a motive. Negative strengths drain it.
public struct MotiveSignal: Equatable, Sendable {
    /// The motive changed by the signal.
    public let motiveType: MotiveType

    /// The motive change per simulated second.
    public let strengthPerSecond: Double

    /// Creates a motive signal.
    public init(motiveType: MotiveType, strengthPerSecond: Double) {
        self.motiveType = motiveType
        self.strengthPerSecond = strengthPerSecond
    }
}

/// An expected motive benefit advertised by an interaction.
///
/// Benefits inform selection and are not applied to motive state directly.
public struct MotiveBenefit: Equatable, Sendable {
    /// The motive expected to change.
    public let motiveType: MotiveType

    /// The expected motive change per simulated second.
    public let expectedStrengthPerSecond: Double

    /// Creates an advertised motive benefit.
    public init(motiveType: MotiveType, expectedStrengthPerSecond: Double) {
        self.motiveType = motiveType
        self.expectedStrengthPerSecond = expectedStrengthPerSecond
    }
}

/// An error encountered while constructing or updating motive data.
public enum MotiveLevelsError: Error, Equatable, Sendable {
    /// The supplied values do not contain every motive.
    case missingMotiveLevels([MotiveType])

    /// A motive value is not finite.
    case nonFiniteMotiveLevel(MotiveType)

    /// The supplied rates do not contain every motive.
    case missingDecayRates([MotiveType])

    /// A decay rate is negative or not finite.
    case invalidDecayRate(MotiveType)

    /// Elapsed time is negative or not finite.
    case invalidElapsedSeconds

    /// A motive signal has a non-finite strength.
    case nonFiniteSignalStrength(MotiveType)
}

/// The per-second decay rate for every motive.
public struct MotiveDecayRates: Equatable, Sendable {
    private let ratesPerSecond: [MotiveType: Double]

    /// Creates a complete table of finite, nonnegative decay rates.
    public init(ratesPerSecond: [MotiveType: Double]) throws {
        let missingMotives = MotiveType.allCases.filter { ratesPerSecond[$0] == nil }
        guard missingMotives.isEmpty else {
            throw MotiveLevelsError.missingDecayRates(missingMotives)
        }

        for motiveType in MotiveType.allCases {
            guard let rate = ratesPerSecond[motiveType],
                  rate.isFinite,
                  rate >= 0
            else {
                throw MotiveLevelsError.invalidDecayRate(motiveType)
            }
        }

        self.ratesPerSecond = ratesPerSecond
    }

    /// Returns the decay rate for a motive.
    public func rate(for motiveType: MotiveType) -> Double {
        ratesPerSecond[motiveType]!
    }
}

/// The complete set of motive values for one simulation entity.
///
/// Values are bounded to `0...100`. Lower values represent greater need.
public struct MotiveLevels: Equatable, Sendable {
    /// The lowest supported motive value.
    public static let minimumValue = 0.0

    /// The highest supported motive value.
    public static let maximumValue = 100.0

    private var levels: [MotiveType: Double]

    /// Creates a complete motive snapshot, clamping finite values to `0...100`.
    ///
    /// - Throws: `MotiveLevelsError` if any motive is missing or has a
    ///   non-finite value.
    public init(levels: [MotiveType: Double]) throws {
        let missingMotives = MotiveType.allCases.filter { levels[$0] == nil }
        guard missingMotives.isEmpty else {
            throw MotiveLevelsError.missingMotiveLevels(missingMotives)
        }

        var validatedLevels: [MotiveType: Double] = [:]
        for motiveType in MotiveType.allCases {
            guard let level = levels[motiveType] else {
                throw MotiveLevelsError.missingMotiveLevels([motiveType])
            }
            guard level.isFinite else {
                throw MotiveLevelsError.nonFiniteMotiveLevel(motiveType)
            }
            validatedLevels[motiveType] = level.clamped(
                to: Self.minimumValue ... Self.maximumValue,
            )
        }

        self.levels = validatedLevels
    }

    /// Returns the value for a motive.
    public func level(for motiveType: MotiveType) -> Double {
        levels[motiveType]!
    }

    /// The lowest motive, using `MotiveType` declaration order to break ties.
    ///
    /// This query checks every motive and is O(number of motive types).
    public var lowest: (motiveType: MotiveType, level: Double) {
        var lowestMotiveType = MotiveType.allCases[0]
        for motiveType in MotiveType.allCases.dropFirst() {
            if level(for: motiveType) < level(for: lowestMotiveType) {
                lowestMotiveType = motiveType
            }
        }

        return (lowestMotiveType, level(for: lowestMotiveType))
    }
}

/// Pure transformations over motive state.
public enum MotiveSystem {
    /// Returns motive state after applying the configured decay rates.
    ///
    /// - Throws: `MotiveLevelsError.invalidElapsedSeconds` if elapsed time
    ///   is negative or not finite.
    public static func decay(
        _ levels: MotiveLevels,
        using rates: MotiveDecayRates,
        overSeconds elapsedSeconds: Double
    ) throws -> MotiveLevels {
        try validate(elapsedSeconds: elapsedSeconds)

        var decayedLevels: [MotiveType: Double] = [:]
        for motiveType in MotiveType.allCases {
            let decayedLevel =
                levels.level(for: motiveType) - rates.rate(for: motiveType) * elapsedSeconds
            decayedLevels[motiveType] = try clamped(decayedLevel, for: motiveType)
        }

        return try MotiveLevels(levels: decayedLevels)
    }

    /// Returns motive state after applying the supplied signals.
    ///
    /// Negative signals drain motives. Results are clamped to `0...100`.
    ///
    /// - Throws: `MotiveLevelsError` if elapsed time or a signal strength
    ///   is invalid, or signal arithmetic produces an undefined value.
    public static func fulfill(
        _ levels: MotiveLevels,
        with signals: [MotiveSignal],
        overSeconds elapsedSeconds: Double
    ) throws -> MotiveLevels {
        try validate(elapsedSeconds: elapsedSeconds)

        var updatedLevels = Dictionary(
            uniqueKeysWithValues: MotiveType.allCases.map {
                ($0, levels.level(for: $0))
            },
        )
        for signal in signals {
            guard signal.strengthPerSecond.isFinite else {
                throw MotiveLevelsError.nonFiniteSignalStrength(signal.motiveType)
            }
            let signalChange = signal.strengthPerSecond * elapsedSeconds
            updatedLevels[signal.motiveType, default: 0] += signalChange
        }

        for motiveType in MotiveType.allCases {
            guard let updatedLevel = updatedLevels[motiveType] else {
                throw MotiveLevelsError.missingMotiveLevels([motiveType])
            }
            updatedLevels[motiveType] = try clamped(updatedLevel, for: motiveType)
        }

        return try MotiveLevels(levels: updatedLevels)
    }

    private static func clamped(_ value: Double, for motiveType: MotiveType) throws -> Double {
        guard !value.isNaN else {
            throw MotiveLevelsError.nonFiniteMotiveLevel(motiveType)
        }
        return value.clamped(to: MotiveLevels.minimumValue ... MotiveLevels.maximumValue)
    }

    private static func validate(elapsedSeconds: Double) throws {
        guard elapsedSeconds.isFinite, elapsedSeconds >= 0 else {
            throw MotiveLevelsError.invalidElapsedSeconds
        }
    }
}
