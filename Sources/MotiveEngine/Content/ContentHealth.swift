/// One interaction of one item definition, shared by every placed instance.
public struct InteractionReference: Codable, Hashable, Sendable {
    /// The item definition that provides the interaction.
    public let itemDefinitionID: ItemDefinitionID

    /// The interaction within that definition.
    public let interactionDefinitionID: InteractionDefinitionID

    /// Creates a reference.
    public init(itemDefinitionID: ItemDefinitionID, interactionDefinitionID: InteractionDefinitionID) {
        self.itemDefinitionID = itemDefinitionID
        self.interactionDefinitionID = interactionDefinitionID
    }

    init(_ offer: InteractionOffer) {
        self.init(itemDefinitionID: offer.itemDefinitionID, interactionDefinitionID: offer.interactionDefinitionID)
    }
}

/// How a session responds to interaction scripts that keep failing.
///
/// A failure starts a cooldown during which free will skips the interaction.
/// After `failuresBeforeDisabling` failures in a row, the script is disabled
/// and the interaction uses its written effects, or the interaction is
/// disabled if it has none. When `disabledInteractionsBeforeDisablingPack`
/// interactions from one content pack have reached that point, the pack and
/// the packs that depend on it are disabled.
public struct ScriptFailurePolicy: Equatable, Sendable {
    /// Simulated seconds free will waits before retrying a failed interaction.
    public let cooldownSeconds: Double

    /// Consecutive failures that disable a script.
    public let failuresBeforeDisabling: Int

    /// Broken interactions in one pack that disable the whole pack.
    public let disabledInteractionsBeforeDisablingPack: Int

    /// Creates the default policy: a 60-second cooldown, three failures,
    /// and three broken interactions per pack.
    public init() {
        cooldownSeconds = 60
        failuresBeforeDisabling = 3
        disabledInteractionsBeforeDisablingPack = 3
    }

    /// Creates a policy.
    ///
    /// - Throws: `ScriptFailurePolicyError` for a cooldown that is not
    ///   positive and finite, or a count below one.
    public init(
        cooldownSeconds: Double,
        failuresBeforeDisabling: Int,
        disabledInteractionsBeforeDisablingPack: Int
    ) throws {
        guard cooldownSeconds.isFinite, cooldownSeconds > 0 else {
            throw ScriptFailurePolicyError.invalidCooldown
        }
        guard failuresBeforeDisabling >= 1, disabledInteractionsBeforeDisablingPack >= 1 else {
            throw ScriptFailurePolicyError.invalidThreshold
        }
        self.cooldownSeconds = cooldownSeconds
        self.failuresBeforeDisabling = failuresBeforeDisabling
        self.disabledInteractionsBeforeDisablingPack = disabledInteractionsBeforeDisablingPack
    }
}

/// An invalid script failure policy.
public enum ScriptFailurePolicyError: Error, Equatable, Sendable {
    /// The cooldown is not positive and finite.
    case invalidCooldown

    /// A failure or broken-interaction threshold is below one.
    case invalidThreshold
}

/// Why a content pack was disabled.
public enum PackDisableReason: Codable, Equatable, Sendable {
    /// Too many of the pack's interactions broke. Listed in the order they broke.
    case failingInteractions([InteractionReference])

    /// A pack this one depends on was disabled.
    case dependencyDisabled(ContentPackID)
}

/// The record of failing scripts and disabled content for a session.
///
/// Save this with the game and pass it back when the session is recreated.
/// Disabled content stays disabled until the player re-enables it with
/// `SimulationCommand.enableInteraction` or `.enablePack`. Entries for
/// content that is no longer installed are kept, so a broken mod stays
/// disabled if it is installed again.
public struct ContentHealth: Codable, Equatable, Sendable {
    /// Consecutive script failures per interaction. A success clears the count.
    public internal(set) var failureCounts: [InteractionReference: Int] = [:]

    /// Remaining cooldown, in simulated seconds, per interaction.
    public internal(set) var cooldowns: [InteractionReference: Double] = [:]

    /// Interactions whose script is disabled. They use their written effects.
    public internal(set) var disabledScripts: Set<InteractionReference> = []

    /// Interactions that can no longer be started.
    public internal(set) var disabledInteractions: Set<InteractionReference> = []

    /// Disabled packs and why. Their items offer nothing.
    public internal(set) var disabledPacks: [ContentPackID: PackDisableReason] = [:]

    /// Interactions that broke, in order, per pack. Used to decide when a
    /// pack is disabled.
    public internal(set) var brokenInteractionsByPack: [ContentPackID: [InteractionReference]] = [:]

    /// Creates an empty record.
    public init() {}

    /// Whether an interaction is waiting out a cooldown.
    public func isCoolingDown(_ interaction: InteractionReference) -> Bool {
        cooldowns[interaction] != nil
    }

    /// Whether an interaction's script is disabled.
    public func isScriptDisabled(_ interaction: InteractionReference) -> Bool {
        disabledScripts.contains(interaction)
    }

    /// Whether an interaction is disabled.
    public func isInteractionDisabled(_ interaction: InteractionReference) -> Bool {
        disabledInteractions.contains(interaction)
    }

    /// Whether a pack is disabled.
    public func isPackDisabled(_ packID: ContentPackID) -> Bool {
        disabledPacks[packID] != nil
    }

    /// Every interaction with any recorded history.
    var allTrackedInteractions: [InteractionReference] {
        Array(failureCounts.keys) + Array(cooldowns.keys) + Array(disabledScripts) + Array(disabledInteractions)
    }

    /// Forgets an interaction's failures, cooldown, and disabled state, and
    /// stops counting it toward disabling its pack.
    mutating func clearHistory(of interaction: InteractionReference) {
        failureCounts[interaction] = nil
        cooldowns[interaction] = nil
        disabledScripts.remove(interaction)
        disabledInteractions.remove(interaction)
        brokenInteractionsByPack = brokenInteractionsByPack
            .mapValues { $0.filter { $0 != interaction } }
            .filter { !$0.value.isEmpty }
    }

    /// Re-enables a pack and every pack disabled because of it, directly or
    /// indirectly. Returns the re-enabled packs, starting with `packID`.
    mutating func enablePack(_ packID: ContentPackID) -> [ContentPackID] {
        var enabled: [ContentPackID] = []
        var pending = [packID]
        while let next = pending.first {
            pending.removeFirst()
            guard disabledPacks.removeValue(forKey: next) != nil || next == packID else {
                continue
            }
            enabled.append(next)
            let dependents = disabledPacks
                .filter { $0.value == .dependencyDisabled(next) }
                .map(\.key)
                .sorted { $0.rawValue < $1.rawValue }
            pending.append(contentsOf: dependents)
        }
        return enabled
    }

    /// Whether the stored values are usable, such as after decoding a save.
    var isValid: Bool {
        failureCounts.values.allSatisfy { $0 >= 1 }
            && cooldowns.values.allSatisfy { $0.isFinite && $0 > 0 }
    }
}
