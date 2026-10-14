/// An input applied at the start of a simulation step.
public enum SimulationCommand: Equatable, Sendable {
    /// Requests an interaction for a Sim.
    case startInteraction(
        simID: SimID,
        itemInstanceID: ItemInstanceID,
        interactionDefinitionID: InteractionDefinitionID
    )

    /// Cancels the Sim's current interaction.
    case cancelInteraction(simID: SimID)

    /// Starts a timed buff on a Sim, replacing one with the same ID.
    case applyBuff(simID: SimID, buff: TimedBuff)

    /// Re-enables an interaction and clears its failure history.
    case enableInteraction(InteractionReference)

    /// Re-enables a pack, the packs disabled because of it, and their
    /// interactions, clearing their failure history.
    case enablePack(ContentPackID)
}

/// An invalid simulation session input or transition.
public enum SimulationSessionError: Error, Equatable, Sendable {
    /// A command refers to a Sim that is not in the session.
    case missingSim(SimID)

    /// An active action refers to an item absent from the session.
    case activeActionItemMissing(simID: SimID, itemInstanceID: ItemInstanceID)

    /// An active action is not defined by the item's current catalog content.
    case activeActionOfferMissing(simID: SimID, itemInstanceID: ItemInstanceID)

    /// An active action targets an item on another lot.
    case activeActionOnDifferentLot(simID: SimID, itemInstanceID: ItemInstanceID)

    /// An active action is already in a terminal state.
    case terminalActiveAction(SimID)

    /// A Sim's initial position overlaps a blocking item.
    case simOverlapsBlockingItem(simID: SimID, itemInstanceID: ItemInstanceID)

    /// A Sim already has an active interaction.
    case simAlreadyInteracting(SimID)

    /// A command refers to an item that is not in the session.
    case missingItem(ItemInstanceID)

    /// The Sim is not currently placed on a lot.
    case simNotOnLot(SimID)

    /// The requested interaction is not offered by the specified item.
    case interactionNotFound(
        itemInstanceID: ItemInstanceID,
        interactionDefinitionID: InteractionDefinitionID
    )

    /// The item is not on the Sim's current lot.
    case itemOnDifferentLot(simID: SimID, itemInstanceID: ItemInstanceID)

    /// No path to a free approach tile exists for the requested interaction.
    case interactionUnreachable(simID: SimID, itemInstanceID: ItemInstanceID)

    /// The interaction could not be started for the listed eligibility reasons.
    case interactionIneligible(
        simID: SimID,
        itemInstanceID: ItemInstanceID,
        reasons: [InteractionIneligibilityReason]
    )

    /// A cancel command refers to a Sim without an active interaction.
    case noActiveInteraction(SimID)

    /// The requested interaction is disabled after repeated script failures.
    case interactionDisabled(InteractionReference)

    /// The requested item belongs to a disabled content pack.
    case packDisabled(ContentPackID)

    /// The supplied content health has a negative count or invalid cooldown.
    case invalidContentHealth
}

/// Coordinates deterministic simulation steps over value state.
///
/// Each step applies commands, motive decay, buffs, autonomous selection,
/// movement, and action execution in the declared phase order. The session
/// does not own concurrency; callers can isolate it at their concurrency
/// boundary.
///
/// Failing interaction scripts are tracked in `contentHealth` according to
/// the session's `ScriptFailurePolicy`. Disabling whole packs requires a
/// session created from a `ContentComposition`.
public struct SimulationSession: Sendable {
    /// The current validated state.
    public private(set) var state: SimulationState

    /// Failing scripts and disabled content. Save this with the game.
    public private(set) var contentHealth: ContentHealth

    private let content: ContentComposition?
    private let scriptFailurePolicy: ScriptFailurePolicy
    private let itemCatalog: ItemDefinitionCatalog
    private let motiveDecayRates: MotiveDecayRates
    private let buffRules: BuffRuleSet
    private let itemLocations: [ItemInstanceID: PlacedItemLocation]

    /// Creates a session and validates item references used by the world.
    ///
    /// Buffs are optional. The default empty rule set applies no buffs.
    /// Without content packs, failing scripts can disable interactions but
    /// not packs.
    ///
    /// - Throws: `ItemDefinitionCatalogError.missingDefinition` when a placed
    ///   item uses an unknown definition, or `SimulationSessionError` when an
    ///   active action does not refer to an item on the Sim's current lot or
    ///   the content health is invalid.
    public init(
        state: SimulationState,
        itemCatalog: ItemDefinitionCatalog,
        motiveDecayRates: MotiveDecayRates,
        buffRules: BuffRuleSet = BuffRuleSet(),
        scriptFailurePolicy: ScriptFailurePolicy = ScriptFailurePolicy(),
        contentHealth: ContentHealth = ContentHealth()
    ) throws {
        try self.init(
            state: state,
            itemCatalog: itemCatalog,
            content: nil,
            motiveDecayRates: motiveDecayRates,
            buffRules: buffRules,
            scriptFailurePolicy: scriptFailurePolicy,
            contentHealth: contentHealth
        )
    }

    /// Creates a session from composed content packs.
    ///
    /// The composition's pack ownership lets repeated script failures disable
    /// a whole pack and the packs that depend on it.
    ///
    /// - Throws: The same errors as `init(state:itemCatalog:motiveDecayRates:buffRules:scriptFailurePolicy:contentHealth:)`.
    public init(
        state: SimulationState,
        content: ContentComposition,
        motiveDecayRates: MotiveDecayRates,
        buffRules: BuffRuleSet = BuffRuleSet(),
        scriptFailurePolicy: ScriptFailurePolicy = ScriptFailurePolicy(),
        contentHealth: ContentHealth = ContentHealth()
    ) throws {
        try self.init(
            state: state,
            itemCatalog: content.catalog,
            content: content,
            motiveDecayRates: motiveDecayRates,
            buffRules: buffRules,
            scriptFailurePolicy: scriptFailurePolicy,
            contentHealth: contentHealth
        )
    }

    private init(
        state: SimulationState,
        itemCatalog: ItemDefinitionCatalog,
        content: ContentComposition?,
        motiveDecayRates: MotiveDecayRates,
        buffRules: BuffRuleSet,
        scriptFailurePolicy: ScriptFailurePolicy,
        contentHealth: ContentHealth
    ) throws {
        guard contentHealth.isValid else {
            throw SimulationSessionError.invalidContentHealth
        }
        var itemLocations: [ItemInstanceID: PlacedItemLocation] = [:]
        for lot in state.lots.values.sorted(by: {
            $0.id.rawValue < $1.id.rawValue
        }) {
            for item in lot.placedItems.sorted(by: {
                $0.id.rawValue < $1.id.rawValue
            }) {
                guard let definition = itemCatalog.definition(for: item.definitionID) else {
                    throw ItemDefinitionCatalogError.missingDefinition(item.definitionID)
                }
                itemLocations[item.id] = PlacedItemLocation(
                    lotID: lot.id,
                    item: item,
                    definition: definition
                )
            }
        }

        for simID in state.sims.keys.sorted(by: {
            $0.rawValue < $1.rawValue
        }) {
            guard let sim = state.sims[simID] else {
                continue
            }
            if let lotID = sim.currentLotID,
               let position = sim.position,
               let lot = state.lots[lotID],
               let item = lot.placedItems.first(where: { item in
                   item.position == position
                       && itemCatalog.definition(for: item.definitionID)?.identity.isBlocking == true
               })
            {
                throw SimulationSessionError.simOverlapsBlockingItem(
                    simID: sim.id,
                    itemInstanceID: item.id
                )
            }

            guard let action = sim.activeAction else {
                continue
            }
            guard action.status == .running else {
                throw SimulationSessionError.terminalActiveAction(sim.id)
            }
            guard let location = itemLocations[action.offer.itemInstanceID] else {
                throw SimulationSessionError.activeActionItemMissing(
                    simID: sim.id,
                    itemInstanceID: action.offer.itemInstanceID
                )
            }
            guard sim.currentLotID == location.lotID else {
                throw SimulationSessionError.activeActionOnDifferentLot(
                    simID: sim.id,
                    itemInstanceID: action.offer.itemInstanceID
                )
            }
            guard try itemCatalog.interactionOffers(for: location.item).contains(action.offer) else {
                throw SimulationSessionError.activeActionOfferMissing(
                    simID: sim.id,
                    itemInstanceID: action.offer.itemInstanceID
                )
            }
        }

        self.state = state
        self.contentHealth = contentHealth
        self.content = content
        self.scriptFailurePolicy = scriptFailurePolicy
        self.itemCatalog = itemCatalog
        self.motiveDecayRates = motiveDecayRates
        self.buffRules = buffRules
        self.itemLocations = itemLocations
    }

    /// Applies one simulation step and returns its resulting snapshot/events.
    ///
    /// Sims are processed in stable-ID order. Commands are applied in the
    /// order supplied, and a command error leaves the session unchanged.
    ///
    /// - Throws: `MotiveLevelsError.invalidElapsedSeconds` for invalid time,
    ///   catalog errors for invalid references, and `SimulationSessionError`
    ///   for invalid commands or action references.
    @discardableResult
    public mutating func step(
        bySeconds elapsedSeconds: Double,
        commands: [SimulationCommand] = []
    ) throws -> SimulationStepResult {
        guard elapsedSeconds.isFinite, elapsedSeconds >= 0 else {
            throw MotiveLevelsError.invalidElapsedSeconds
        }

        var sims = state.sims
        var health = contentHealth
        var events: [SimulationEvent] = []
        var suppressingAutonomy: Set<SimID> = []

        for command in commands {
            try apply(
                command,
                to: &sims,
                health: &health,
                suppressingAutonomy: &suppressingAutonomy,
                recording: &events
            )
        }
        health.cooldowns = health.cooldowns
            .mapValues { $0 - elapsedSeconds }
            .filter { $0.value > 0 }
        try stopActionsOnDisabledContent(in: &sims, health: health, recording: &events)

        for simID in sortedSimIDs(in: sims) {
            guard let sim = sims[simID] else {
                continue
            }
            let decayedMotives = try MotiveSystem.decay(
                sim.motives,
                using: motiveDecayRates,
                overSeconds: elapsedSeconds
            )
            guard decayedMotives != sim.motives else {
                continue
            }
            sims[simID] = replacing(sim, motives: decayedMotives)
            events.append(.motivesChanged(simID: simID, motives: decayedMotives))
        }

        try applyBuffs(to: &sims, bySeconds: elapsedSeconds, recording: &events)
        try selectAutonomousInteractions(
            for: &sims,
            health: &health,
            suppressing: suppressingAutonomy,
            recording: &events
        )
        try moveActors(in: &sims, recording: &events)
        try advanceActions(
            in: &sims,
            bySeconds: elapsedSeconds,
            recording: &events
        )

        let nextState = try SimulationState(
            sims: Array(sims.values),
            households: Array(state.households.values),
            lots: Array(state.lots.values)
        )
        state = nextState
        contentHealth = health
        return SimulationStepResult(
            snapshot: SimulationSnapshot(state: nextState),
            events: events
        )
    }

    private func apply(
        _ command: SimulationCommand,
        to sims: inout [SimID: SimStateData],
        health: inout ContentHealth,
        suppressingAutonomy: inout Set<SimID>,
        recording events: inout [SimulationEvent]
    ) throws {
        switch command {
        case let .startInteraction(simID, itemInstanceID, interactionID):
            guard let sim = sims[simID] else {
                throw SimulationSessionError.missingSim(simID)
            }
            guard sim.activeAction == nil else {
                throw SimulationSessionError.simAlreadyInteracting(simID)
            }
            guard let location = itemLocations[itemInstanceID] else {
                throw SimulationSessionError.missingItem(itemInstanceID)
            }
            guard let currentLotID = sim.currentLotID else {
                throw SimulationSessionError.simNotOnLot(simID)
            }
            guard currentLotID == location.lotID else {
                throw SimulationSessionError.itemOnDifferentLot(
                    simID: simID,
                    itemInstanceID: itemInstanceID
                )
            }

            let offers = try itemCatalog.interactionOffers(for: location.item)
            guard let offer = offers.first(where: {
                $0.interactionDefinitionID == interactionID
            }) else {
                throw SimulationSessionError.interactionNotFound(
                    itemInstanceID: itemInstanceID,
                    interactionDefinitionID: interactionID
                )
            }
            if let packID = disabledPack(of: offer, in: health) {
                throw SimulationSessionError.packDisabled(packID)
            }
            guard !health.isInteractionDisabled(InteractionReference(offer)) else {
                throw SimulationSessionError.interactionDisabled(InteractionReference(offer))
            }
            let interactionEligibility = try eligibility(
                for: offer,
                sim: sim,
                sims: sims,
                location: location
            )
            guard interactionEligibility.isEligible else {
                throw SimulationSessionError.interactionIneligible(
                    simID: simID,
                    itemInstanceID: itemInstanceID,
                    reasons: interactionEligibility.reasons
                )
            }
            guard canReachItem(for: sim, offer: offer, simID: simID, sims: sims) else {
                throw SimulationSessionError.interactionUnreachable(
                    simID: simID,
                    itemInstanceID: itemInstanceID
                )
            }

            let action = try startAction(
                offer,
                initiatedBy: .playerCommand,
                for: sim,
                health: &health,
                recording: &events
            )
            if action.status == .running {
                sims[simID] = replacingAction(sim, with: action)
            } else {
                // The command still decides this step, so autonomy waits.
                suppressingAutonomy.insert(simID)
            }

        case let .cancelInteraction(simID):
            guard let sim = sims[simID] else {
                throw SimulationSessionError.missingSim(simID)
            }
            guard let action = sim.activeAction else {
                throw SimulationSessionError.noActiveInteraction(simID)
            }
            let interrupted = try InteractionActionSystem.interrupt(
                action,
                because: .cancelled
            )
            sims[simID] = replacingAction(sim, with: nil)
            suppressingAutonomy.insert(simID)
            events.append(.actionChanged(simID: simID, action: interrupted))

        case let .applyBuff(simID, buff):
            guard let sim = sims[simID] else {
                throw SimulationSessionError.missingSim(simID)
            }
            let timedBuffs = sim.timedBuffs.filter { $0.id != buff.id } + [buff]
            sims[simID] = replacing(sim, timedBuffs: timedBuffs)
            events.append(.timedBuffApplied(simID: simID, buff: buff))

        case let .enableInteraction(interaction):
            health.clearHistory(of: interaction)
            events.append(.interactionEnabled(interaction))

        case let .enablePack(packID):
            for enabledPackID in health.enablePack(packID) {
                for interaction in Set(health.allTrackedInteractions) where owner(of: interaction) == enabledPackID {
                    health.clearHistory(of: interaction)
                }
                health.brokenInteractionsByPack[enabledPackID] = nil
                events.append(.packEnabled(enabledPackID))
            }
        }
    }

    private func applyBuffs(
        to sims: inout [SimID: SimStateData],
        bySeconds elapsedSeconds: Double,
        recording events: inout [SimulationEvent]
    ) throws {
        for simID in sortedSimIDs(in: sims) {
            guard let sim = sims[simID],
                  !buffRules.isEmpty || !sim.timedBuffs.isEmpty
            else {
                continue
            }
            let context = BuffContext(
                sim: sim,
                lot: sim.currentLotID.flatMap { state.lots[$0] },
                itemCatalog: itemCatalog
            )
            let evaluation = try BuffSystem.evaluate(
                buffRules,
                in: context,
                overSeconds: elapsedSeconds
            )
            guard !evaluation.effects.isEmpty else {
                continue
            }
            events.append(.buffsApplied(simID: simID, effects: evaluation.effects))
            sims[simID] = replacing(sim, motives: evaluation.motives, timedBuffs: evaluation.timedBuffs)
            if evaluation.motives != sim.motives {
                events.append(.motivesChanged(simID: simID, motives: evaluation.motives))
            }
            for buffID in evaluation.expiredBuffIDs {
                events.append(.timedBuffExpired(simID: simID, buffID: buffID))
            }
        }
    }

    private func selectAutonomousInteractions(
        for sims: inout [SimID: SimStateData],
        health: inout ContentHealth,
        suppressing suppressedSimIDs: Set<SimID>,
        recording events: inout [SimulationEvent]
    ) throws {
        for simID in sortedSimIDs(in: sims) {
            guard let sim = sims[simID],
                  sim.activeAction == nil,
                  !suppressedSimIDs.contains(simID),
                  let lotID = sim.currentLotID,
                  let lot = state.lots[lotID]
            else {
                continue
            }

            var eligibleOffers: [InteractionOffer] = []
            for item in lot.placedItems.sorted(by: {
                $0.id.rawValue < $1.id.rawValue
            }) {
                guard let location = itemLocations[item.id] else {
                    continue
                }
                for offer in try itemCatalog.interactionOffers(for: item) {
                    let interaction = InteractionReference(offer)
                    guard disabledPack(of: offer, in: health) == nil,
                          !health.isInteractionDisabled(interaction),
                          !health.isCoolingDown(interaction),
                          try eligibility(for: offer, sim: sim, sims: sims, location: location)
                            .isEligible,
                          canReachItem(for: sim, offer: offer, simID: simID, sims: sims)
                    else {
                        continue
                    }
                    eligibleOffers.append(offer)
                }
            }

            // A useful offer whose script fails is reported, then the next
            // useful offer is tried, so one faulty script cannot idle a Sim.
            let ranking = try AutonomyScoringSystem.rank(eligibleOffers, for: sim.motives)
            for scored in ranking.rankedOffers where scored.score > 0 {
                let interaction = InteractionReference(scored.offer)
                // An earlier failure in this loop may have disabled this offer.
                guard disabledPack(of: scored.offer, in: health) == nil,
                      !health.isInteractionDisabled(interaction),
                      !health.isCoolingDown(interaction)
                else {
                    continue
                }
                let action = try startAction(
                    scored.offer,
                    initiatedBy: .autonomy,
                    for: sim,
                    health: &health,
                    recording: &events
                )
                if action.status == .running {
                    sims[simID] = replacingAction(sim, with: action)
                    break
                }
            }
        }
    }

    /// Starts an action and records the result in `health`.
    ///
    /// An offer whose script is disabled uses its written effects. A script
    /// failure returns an already-failed action rather than throwing, so one
    /// faulty script cannot stop the step, then escalates according to the
    /// failure policy.
    private func startAction(
        _ offer: InteractionOffer,
        initiatedBy initiator: InteractionActionInitiator,
        for sim: SimStateData,
        health: inout ContentHealth,
        recording events: inout [SimulationEvent]
    ) throws -> InteractionActionState {
        let interaction = InteractionReference(offer)
        guard let script = offer.script, !health.isScriptDisabled(interaction) else {
            let action = InteractionActionSystem.start(offer, initiatedBy: initiator)
            events.append(.actionChanged(simID: sim.id, action: action))
            return action
        }

        let failure: InteractionScriptFailure
        do {
            let result = try InteractionScriptSystem.evaluate(
                script,
                input: InteractionScriptInput(sim: sim, offer: offer)
            )
            health.failureCounts[interaction] = nil
            let action = InteractionActionSystem.start(
                offer,
                initiatedBy: initiator,
                motiveEffects: result.motiveEffects
            )
            events.append(.actionChanged(simID: sim.id, action: action))
            return action
        } catch let error as RuntimeError {
            failure = .runtime(error)
        } catch let error as InteractionScriptError {
            failure = .invalidEffect(error)
        }

        let action = try InteractionActionSystem.fail(
            InteractionActionSystem.start(offer, initiatedBy: initiator),
            because: .scriptFailed(failure)
        )
        events.append(.actionChanged(simID: sim.id, action: action))
        recordFailure(of: interaction, writtenEffects: offer.motiveEffects, health: &health, recording: &events)
        return action
    }

    /// Applies the failure policy after one script failure.
    private func recordFailure(
        of interaction: InteractionReference,
        writtenEffects: [MotiveSignal],
        health: inout ContentHealth,
        recording events: inout [SimulationEvent]
    ) {
        let failures = health.failureCounts[interaction, default: 0] + 1
        guard failures >= scriptFailurePolicy.failuresBeforeDisabling else {
            health.failureCounts[interaction] = failures
            health.cooldowns[interaction] = scriptFailurePolicy.cooldownSeconds
            events.append(.interactionCoolingDown(
                interaction,
                failureCount: failures,
                seconds: scriptFailurePolicy.cooldownSeconds
            ))
            return
        }

        health.failureCounts[interaction] = nil
        health.cooldowns[interaction] = nil
        if writtenEffects.isEmpty {
            health.disabledInteractions.insert(interaction)
            events.append(.interactionDisabled(interaction))
        } else {
            health.disabledScripts.insert(interaction)
            events.append(.scriptDisabled(interaction))
        }

        guard let packID = owner(of: interaction), let content else {
            return
        }
        if !health.brokenInteractionsByPack[packID, default: []].contains(interaction) {
            health.brokenInteractionsByPack[packID, default: []].append(interaction)
        }
        let broken = health.brokenInteractionsByPack[packID, default: []]
        guard broken.count >= scriptFailurePolicy.disabledInteractionsBeforeDisablingPack,
              !health.isPackDisabled(packID)
        else {
            return
        }
        health.disabledPacks[packID] = .failingInteractions(broken)
        events.append(.packDisabled(packID, reason: .failingInteractions(broken)))
        for dependent in content.dependents(of: packID) where !health.isPackDisabled(dependent) {
            let reason = PackDisableReason.dependencyDisabled(packID)
            health.disabledPacks[dependent] = reason
            events.append(.packDisabled(dependent, reason: reason))
        }
    }

    /// Fails running actions whose interaction or pack has been disabled.
    private func stopActionsOnDisabledContent(
        in sims: inout [SimID: SimStateData],
        health: ContentHealth,
        recording events: inout [SimulationEvent]
    ) throws {
        for simID in sortedSimIDs(in: sims) {
            guard let sim = sims[simID],
                  let action = sim.activeAction,
                  action.status == .running,
                  disabledPack(of: action.offer, in: health) != nil
                    || health.isInteractionDisabled(InteractionReference(action.offer))
            else {
                continue
            }
            let failed = try InteractionActionSystem.fail(action, because: .itemUnavailable)
            sims[simID] = replacingAction(sim, with: nil)
            events.append(.actionChanged(simID: simID, action: failed))
        }
    }

    /// The pack that owns an interaction's definition, when content packs are known.
    private func owner(of interaction: InteractionReference) -> ContentPackID? {
        content?.owner(of: interaction.itemDefinitionID)
    }

    /// The offer's pack, if that pack is disabled.
    private func disabledPack(of offer: InteractionOffer, in health: ContentHealth) -> ContentPackID? {
        guard let packID = content?.owner(of: offer.itemDefinitionID), health.isPackDisabled(packID) else {
            return nil
        }
        return packID
    }

    private func moveActors(
        in sims: inout [SimID: SimStateData],
        recording events: inout [SimulationEvent]
    ) throws {
        for simID in sortedSimIDs(in: sims) {
            guard let sim = sims[simID],
                  let action = sim.activeAction,
                  action.status == .running
            else {
                continue
            }

            switch routeStep(for: sim, offer: action.offer, simID: simID, sims: sims) {
            case .arrived:
                continue
            case let .move(to: position):
                guard let previousPosition = sim.position,
                      previousPosition != position
                else {
                    continue
                }
                sims[simID] = replacing(sim, position: position)
                events.append(
                    .positionChanged(simID: simID, from: previousPosition, to: position)
                )
            case .unreachable:
                guard routeStep(
                    for: sim,
                    offer: action.offer,
                    simID: simID,
                    sims: sims,
                    ignoringOccupants: true
                ) == .unreachable else {
                    continue
                }
                let failed = try InteractionActionSystem.fail(
                    action,
                    because: .executionFailed
                )
                sims[simID] = replacingAction(sim, with: nil)
                events.append(.actionChanged(simID: simID, action: failed))
            }
        }
    }

    private func advanceActions(
        in sims: inout [SimID: SimStateData],
        bySeconds elapsedSeconds: Double,
        recording events: inout [SimulationEvent]
    ) throws {
        for simID in sortedSimIDs(in: sims) {
            guard let sim = sims[simID],
                  let action = sim.activeAction,
                  action.status == .running,
                  routeStep(for: sim, offer: action.offer, simID: simID, sims: sims) == .arrived
            else {
                continue
            }

            let update = try InteractionActionSystem.advance(
                action,
                motives: sim.motives,
                bySeconds: elapsedSeconds
            )
            let activeAction = update.action.status == .running ? update.action : nil
            sims[simID] = replacingAction(
                replacing(sim, motives: update.motives),
                with: activeAction
            )
            if update.motives != sim.motives {
                events.append(.motivesChanged(simID: simID, motives: update.motives))
            }
            if update.action != action {
                events.append(.actionChanged(simID: simID, action: update.action))
            }
        }
    }

    private func eligibility(
        for offer: InteractionOffer,
        sim: SimStateData,
        sims: [SimID: SimStateData],
        location: PlacedItemLocation
    ) throws -> InteractionEligibility {
        let actor = InteractionActorSnapshot(
            posture: sim.posture,
            isAvailable: sim.activeAction == nil
        )
        let item = try InteractionItemSnapshot(
            itemInstanceID: location.item.id,
            isAvailable: true,
            capacity: location.definition.interactionCapacity,
            occupancy: occupancy(of: location.item.id, in: sims)
        )
        return InteractionEligibilitySystem.evaluate(offer, actor: actor, item: item)
    }

    private func routeStep(
        for sim: SimStateData,
        offer: InteractionOffer,
        simID: SimID,
        sims: [SimID: SimStateData],
        ignoringOccupants: Bool = false
    ) -> InteractionRouteStep {
        guard let location = itemLocations[offer.itemInstanceID],
              sim.currentLotID == location.lotID,
              let position = sim.position,
              let lot = state.lots[location.lotID]
        else {
            return .unreachable
        }

        let blocked = Set(lot.placedItems.compactMap { item -> GridPosition? in
            guard itemCatalog.definition(for: item.definitionID)?.identity.isBlocking == true else {
                return nil
            }
            return item.position
        })
        let occupied = Set(sims.values.compactMap { otherSim -> GridPosition? in
            guard otherSim.id != simID,
                  otherSim.currentLotID == location.lotID,
                  !ignoringOccupants
            else {
                return nil
            }
            return otherSim.position
        })
        return InteractionRoutingSystem.nextStep(
            from: position,
            towardItemAt: location.item.position,
            blocked: blocked,
            occupied: occupied,
            bounds: lot.bounds
        )
    }

    private func canReachItem(
        for sim: SimStateData,
        offer: InteractionOffer,
        simID: SimID,
        sims: [SimID: SimStateData]
    ) -> Bool {
        routeStep(for: sim, offer: offer, simID: simID, sims: sims) != .unreachable
            || routeStep(
                for: sim,
                offer: offer,
                simID: simID,
                sims: sims,
                ignoringOccupants: true
            ) != .unreachable
    }

    private func occupancy(of itemInstanceID: ItemInstanceID, in sims: [SimID: SimStateData]) -> Int {
        sims.values.reduce(into: 0) { count, sim in
            guard let action = sim.activeAction,
                  action.status == .running,
                  action.offer.itemInstanceID == itemInstanceID
            else {
                return
            }
            count += 1
        }
    }

    private func sortedSimIDs(in sims: [SimID: SimStateData]) -> [SimID] {
        sims.keys.sorted { $0.rawValue < $1.rawValue }
    }

    private func replacing(
        _ sim: SimStateData,
        motives: MotiveLevels? = nil,
        position: GridPosition? = nil,
        timedBuffs: [TimedBuff]? = nil
    ) -> SimStateData {
        SimStateData(
            id: sim.id,
            motives: motives ?? sim.motives,
            posture: sim.posture,
            currentLotID: sim.currentLotID,
            position: position ?? sim.position,
            activeAction: sim.activeAction,
            timedBuffs: timedBuffs ?? sim.timedBuffs
        )
    }

    private func replacingAction(
        _ sim: SimStateData,
        with activeAction: InteractionActionState?
    ) -> SimStateData {
        SimStateData(
            id: sim.id,
            motives: sim.motives,
            posture: sim.posture,
            currentLotID: sim.currentLotID,
            position: sim.position,
            activeAction: activeAction,
            timedBuffs: sim.timedBuffs
        )
    }
}

private struct PlacedItemLocation: Sendable {
    let lotID: LotID
    let item: PlacedItem
    let definition: ItemDefinition
}
