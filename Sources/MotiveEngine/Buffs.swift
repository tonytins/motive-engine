/// A stable identifier for one buff rule.
public struct BuffID: Codable, Hashable, Sendable {
    /// The content-defined identifier.
    public let rawValue: String

    /// Creates an identifier from a nonempty string.
    public init?(_ rawValue: String) {
        guard !rawValue.isEmpty else { return nil }
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard !rawValue.isEmpty else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Buff ID must not be empty",
            )
        }
        self.rawValue = rawValue
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// The read-only inputs available to a buff rule for one Sim.
public struct BuffContext: Sendable {
    /// The Sim the buff is evaluated for.
    public let sim: SimStateData

    /// The Sim's current lot, if it is on one.
    public let lot: LotState?

    /// The item content used to resolve placed items on the lot.
    public let itemCatalog: ItemDefinitionCatalog

    /// Creates the inputs for evaluating buffs on one Sim.
    public init(sim: SimStateData, lot: LotState?, itemCatalog: ItemDefinitionCatalog) {
        self.sim = sim
        self.lot = lot
        self.itemCatalog = itemCatalog
    }
}

/// A passive, unchosen effect on a Sim's motives.
///
/// A rule reports per-second motive signals for a context. It must be pure:
/// the same context returns the same signals, and evaluating a rule does not
/// change any state. `BuffSystem` applies the signals over elapsed time.
public protocol BuffRule: Sendable {
    /// The stable identity used for ordering and attribution.
    var id: BuffID { get }

    /// Returns the per-second motive signals this rule applies to the Sim.
    ///
    /// Return an empty array when the rule does not apply.
    func signals(in context: BuffContext) throws -> [MotiveSignal]
}

/// An invalid buff rule set or rule result.
public enum BuffError: Error, Equatable, Sendable {
    /// Two rules use the same identity.
    case duplicateBuffID(BuffID)

    /// A rule produced a signal with a non-finite strength.
    case nonFiniteSignal(buffID: BuffID, motiveType: MotiveType)

    /// An ambient radius is negative.
    case invalidRadius

    /// A timed buff's remaining time is not positive and finite.
    case invalidDuration(BuffID)
}

/// A buff that applies fixed signals to one Sim for a limited time.
///
/// Timed buffs are instance state stored on `SimStateData`, unlike rules,
/// which hold no state. Start one with `SimulationCommand.applyBuff`.
public struct TimedBuff: Equatable, Sendable {
    /// The stable identity. A Sim has at most one timed buff per ID.
    public let id: BuffID

    /// The per-second motive signals applied while the buff lasts.
    public let signals: [MotiveSignal]

    /// The simulated seconds left before the buff expires.
    public let remainingSeconds: Double

    /// Creates a timed buff lasting `durationSeconds`.
    ///
    /// - Throws: `BuffError.invalidDuration` if the duration is not positive
    ///   and finite, or `BuffError.nonFiniteSignal` for a non-finite signal.
    public init(id: BuffID, signals: [MotiveSignal], durationSeconds: Double) throws {
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw BuffError.invalidDuration(id)
        }
        for signal in signals where !signal.strengthPerSecond.isFinite {
            throw BuffError.nonFiniteSignal(buffID: id, motiveType: signal.motiveType)
        }
        self.id = id
        self.signals = signals
        remainingSeconds = durationSeconds
    }
}

/// Buff rules ordered by stable identity.
public struct BuffRuleSet: Sendable {
    /// Rules sorted by `BuffID`.
    public let rules: [any BuffRule]

    /// Creates an empty rule set that applies no buffs.
    public init() {
        rules = []
    }

    /// Creates a rule set and rejects duplicate rule identities.
    ///
    /// - Throws: `BuffError.duplicateBuffID` if two rules share an ID.
    public init(rules: [any BuffRule]) throws {
        var seenIDs: Set<BuffID> = []
        for rule in rules {
            guard seenIDs.insert(rule.id).inserted else {
                throw BuffError.duplicateBuffID(rule.id)
            }
        }
        self.rules = rules.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    /// Whether the set contains no rules.
    public var isEmpty: Bool {
        rules.isEmpty
    }
}

/// The per-second signals one buff rule contributed for a Sim.
public struct BuffEffect: Equatable, Sendable {
    /// The rule that produced the signals.
    public let buffID: BuffID

    /// The per-second motive signals, in the order the rule returned them.
    public let signals: [MotiveSignal]

    /// Creates an attributed buff effect.
    public init(buffID: BuffID, signals: [MotiveSignal]) {
        self.buffID = buffID
        self.signals = signals
    }
}

/// The result of applying buffs to one Sim over elapsed time.
public struct BuffEvaluation: Equatable, Sendable {
    /// Effects from rules that applied, ordered by buff ID, followed by
    /// effects from the Sim's timed buffs, ordered by buff ID.
    public let effects: [BuffEffect]

    /// Motive values after applying every effect.
    public let motives: MotiveLevels

    /// The Sim's timed buffs with time remaining, ordered by buff ID.
    public let timedBuffs: [TimedBuff]

    /// Timed buffs that ran out during this evaluation, ordered by buff ID.
    public let expiredBuffIDs: [BuffID]
}

/// Pure buff evaluation and application.
public enum BuffSystem {
    /// Evaluates every rule and timed buff for one Sim and applies their signals.
    ///
    /// Rules run in `BuffID` order. Rules that return no signals are omitted
    /// from the effects. Each of the Sim's timed buffs applies only for its
    /// remaining time, then expires. All changes are summed before the
    /// result is clamped, so the motive result does not depend on order.
    /// Zero elapsed time reports effects but leaves motives and timed buffs
    /// unchanged.
    ///
    /// - Throws: `BuffError.nonFiniteSignal` for an invalid rule result,
    ///   `MotiveLevelsError.invalidElapsedSeconds` for invalid time, or any
    ///   error thrown by a rule.
    public static func evaluate(
        _ ruleSet: BuffRuleSet,
        in context: BuffContext,
        overSeconds elapsedSeconds: Double
    ) throws -> BuffEvaluation {
        guard elapsedSeconds.isFinite, elapsedSeconds >= 0 else {
            throw MotiveLevelsError.invalidElapsedSeconds
        }

        var effects: [BuffEffect] = []
        // Each change is a rate multiplied by that effect's own active time.
        var changes: [MotiveSignal] = []
        for rule in ruleSet.rules {
            let signals = try rule.signals(in: context)
            guard !signals.isEmpty else {
                continue
            }
            for signal in signals where !signal.strengthPerSecond.isFinite {
                throw BuffError.nonFiniteSignal(buffID: rule.id, motiveType: signal.motiveType)
            }
            effects.append(BuffEffect(buffID: rule.id, signals: signals))
            changes += signals.map { scaled($0, by: elapsedSeconds) }
        }

        var remainingBuffs: [TimedBuff] = []
        var expiredBuffIDs: [BuffID] = []
        for buff in context.sim.timedBuffs.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            let activeSeconds = min(elapsedSeconds, buff.remainingSeconds)
            effects.append(BuffEffect(buffID: buff.id, signals: buff.signals))
            changes += buff.signals.map { scaled($0, by: activeSeconds) }
            let remainingSeconds = buff.remainingSeconds - activeSeconds
            if remainingSeconds > 0 {
                remainingBuffs.append(try TimedBuff(
                    id: buff.id,
                    signals: buff.signals,
                    durationSeconds: remainingSeconds
                ))
            } else {
                expiredBuffIDs.append(buff.id)
            }
        }

        let motives = try MotiveSystem.fulfill(context.sim.motives, with: changes, overSeconds: 1)
        return BuffEvaluation(
            effects: effects,
            motives: motives,
            timedBuffs: remainingBuffs,
            expiredBuffIDs: expiredBuffIDs
        )
    }

    private static func scaled(_ signal: MotiveSignal, by seconds: Double) -> MotiveSignal {
        MotiveSignal(motiveType: signal.motiveType, strengthPerSecond: signal.strengthPerSecond * seconds)
    }
}

/// Applies the signals of ambient items near a Sim.
///
/// An item is ambient when its definition carries the `.ambient` modifier.
/// Every ambient item on the Sim's current lot within `radius` tiles,
/// measured by Manhattan distance, contributes its definition's signals.
/// A Sim without a lot or position receives nothing. Ambient items are
/// visited in item-instance ID order.
public struct AmbientBuffRule: BuffRule {
    public let id: BuffID

    /// The maximum Manhattan distance at which an ambient item applies.
    public let radius: Int

    /// Creates an ambient rule.
    ///
    /// - Throws: `BuffError.invalidRadius` if `radius` is negative.
    public init(id: BuffID, radius: Int) throws {
        guard radius >= 0 else {
            throw BuffError.invalidRadius
        }
        self.id = id
        self.radius = radius
    }

    public func signals(in context: BuffContext) throws -> [MotiveSignal] {
        guard let lot = context.lot,
              context.sim.currentLotID == lot.id,
              let position = context.sim.position
        else {
            return []
        }

        var signals: [MotiveSignal] = []
        for item in lot.placedItems.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            guard item.position.distance(to: position) <= radius else {
                continue
            }
            guard let definition = context.itemCatalog.definition(for: item.definitionID) else {
                throw ItemDefinitionCatalogError.missingDefinition(item.definitionID)
            }
            signals.append(contentsOf: definition.buffSignals)
        }
        return signals
    }
}
