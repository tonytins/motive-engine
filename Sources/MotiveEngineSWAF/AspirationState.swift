import MotiveEngine

/// Game-controlled settings for one Sim's wants and fears.
///
/// Replace a state's profile whenever the game changes these, for example
/// when a Sim gains a want slot or a new tag.
public struct AspirationProfile: Equatable, Sendable {
    /// Tags that shape which entries are rolled.
    public let tags: Set<SWAFTag>

    /// The number of want slots.
    public let wantSlots: Int

    /// The number of fear slots.
    public let fearSlots: Int

    /// The number of entries that can be locked at once.
    public let lockLimit: Int

    /// Whether fulfillment changes the aspiration bar.
    ///
    /// Reward points change either way. Turn this off for Sims, such as
    /// townies, whose bar should not move.
    public let tracksAspiration: Bool

    /// Creates a profile. The defaults are four wants, three fears, and one lock.
    ///
    /// - Throws: `AspirationError.invalidProfile` for a negative count.
    public init(
        tags: Set<SWAFTag> = [],
        wantSlots: Int = 4,
        fearSlots: Int = 3,
        lockLimit: Int = 1,
        tracksAspiration: Bool = true
    ) throws {
        guard wantSlots >= 0, fearSlots >= 0, lockLimit >= 0 else {
            throw AspirationError.invalidProfile
        }
        self.tags = tags
        self.wantSlots = wantSlots
        self.fearSlots = fearSlots
        self.lockLimit = lockLimit
        self.tracksAspiration = tracksAspiration
    }
}

/// One want or fear currently shown to the player.
public struct WantFearSlot: Equatable, Sendable {
    /// The rolled definition.
    public let definitionID: WantFearID

    /// Whether the entry is exempt from rerolls until fulfilled.
    public let isLocked: Bool

    /// Creates a board entry.
    public init(definitionID: WantFearID, isLocked: Bool = false) {
        self.definitionID = definitionID
        self.isLocked = isLocked
    }
}

/// One Sim's wants and fears board, aspiration, and reward points.
///
/// A new Sim starts with an empty board; call `AspirationSystem.reroll` to
/// fill it. A saved board can be restored by passing its slots.
public struct AspirationState: Equatable, Sendable {
    /// The lowest aspiration value.
    public static let minimumAspiration = MotiveLevels.minimumValue

    /// The highest aspiration value.
    public static let maximumAspiration = MotiveLevels.maximumValue

    /// The Sim this state belongs to.
    public let simID: SimID

    /// Game-controlled settings, applied at the next roll.
    public var profile: AspirationProfile

    /// Current wants in slot order.
    public internal(set) var wants: [WantFearSlot]

    /// Current fears in slot order.
    public internal(set) var fears: [WantFearSlot]

    /// The aspiration bar, from 0 to 100.
    public internal(set) var aspiration: Double

    /// Reward points available to spend. Never negative.
    public internal(set) var rewardPoints: Int

    var randomState: UInt64

    /// Creates a state, optionally restoring a saved board.
    ///
    /// The seed makes every roll repeatable. Board entries are checked
    /// against the catalog when an operation uses them.
    ///
    /// - Throws: `AspirationError` if aspiration is non-finite or outside
    ///   `0...100`, reward points are negative, or an entry appears twice.
    public init(
        simID: SimID,
        profile: AspirationProfile,
        wants: [WantFearSlot] = [],
        fears: [WantFearSlot] = [],
        aspiration: Double = 50,
        rewardPoints: Int = 0,
        seed: UInt64
    ) throws {
        var seenIDs: Set<WantFearID> = []
        for slot in wants + fears {
            guard seenIDs.insert(slot.definitionID).inserted else {
                throw AspirationError.duplicateBoardEntry(slot.definitionID)
            }
        }
        guard aspiration.isFinite,
              (Self.minimumAspiration ... Self.maximumAspiration).contains(aspiration)
        else {
            throw AspirationError.invalidAspiration
        }
        guard rewardPoints >= 0 else {
            throw AspirationError.invalidRewardPoints
        }
        self.simID = simID
        self.profile = profile
        self.wants = wants
        self.fears = fears
        self.aspiration = aspiration
        self.rewardPoints = rewardPoints
        randomState = seed
    }

    /// The board for one kind, in slot order.
    public func slots(for kind: WantFearKind) -> [WantFearSlot] {
        kind == .want ? wants : fears
    }

    mutating func setSlots(_ slots: [WantFearSlot], for kind: WantFearKind) {
        switch kind {
        case .want: wants = slots
        case .fear: fears = slots
        }
    }

    /// Returns a uniform value in `0..<1` and advances the generator.
    mutating func nextUnitInterval() -> Double {
        // SplitMix64 keeps rolls deterministic for a given seed.
        randomState &+= 0x9E37_79B9_7F4A_7C15
        var value = randomState
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value >> 11) * 0x1.0p-53
    }
}

/// An invalid aspiration state or operation.
public enum AspirationError: Error, Equatable, Sendable {
    /// A slot count or lock limit is negative.
    case invalidProfile

    /// Aspiration is non-finite or outside `0...100`.
    case invalidAspiration

    /// Reward points are negative.
    case invalidRewardPoints

    /// A board entry refers to a definition missing from the catalog.
    case missingDefinition(WantFearID)

    /// An entry appears more than once on a board.
    case duplicateBoardEntry(WantFearID)

    /// A board entry is shown as a want but defined as a fear, or the reverse.
    case kindMismatch(WantFearID)

    /// The entry is not on the Sim's board.
    case notOnBoard(WantFearID)

    /// The Sim already has as many locked entries as its profile allows.
    case lockLimitReached

    /// A decay rate or elapsed time is negative or non-finite.
    case invalidDecay
}
