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
}

/// Coordinates deterministic simulation steps over value state.
///
/// Each step applies commands, motive decay, buffs, autonomous selection,
/// movement, and action execution in the declared phase order. The session
/// does not own concurrency; callers can isolate it at their concurrency
/// boundary.
public struct SimulationSession: Sendable {
    /// The current validated state.
    public private(set) var state: SimulationState

    private let itemCatalog: ItemDefinitionCatalog
    private let motiveDecayRates: MotiveDecayRates
    private let buffRules: BuffRuleSet
    private let itemLocations: [ItemInstanceID: PlacedItemLocation]

    /// Creates a session and validates item references used by the world.
    ///
    /// Buffs are optional. The default empty rule set applies no buffs.
    ///
    /// - Throws: `ItemDefinitionCatalogError.missingDefinition` when a placed
    ///   item uses an unknown definition, or `SimulationSessionError` when an
    ///   active action does not refer to an item on the Sim's current lot.
    public init(
        state: SimulationState,
        itemCatalog: ItemDefinitionCatalog,
        motiveDecayRates: MotiveDecayRates,
        buffRules: BuffRuleSet = BuffRuleSet()
    ) throws {
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
        var events: [SimulationEvent] = []
        var suppressingAutonomy: Set<SimID> = []

        for command in commands {
            try apply(
                command,
                to: &sims,
                suppressingAutonomy: &suppressingAutonomy,
                recording: &events
            )
        }

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
        return SimulationStepResult(
            snapshot: SimulationSnapshot(state: nextState),
            events: events
        )
    }

    private func apply(
        _ command: SimulationCommand,
        to sims: inout [SimID: SimStateData],
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

            let action = InteractionActionSystem.start(offer, initiatedBy: .playerCommand)
            sims[simID] = replacingAction(sim, with: action)
            events.append(.actionChanged(simID: simID, action: action))

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
        }
    }

    private func applyBuffs(
        to sims: inout [SimID: SimStateData],
        bySeconds elapsedSeconds: Double,
        recording events: inout [SimulationEvent]
    ) throws {
        guard !buffRules.isEmpty else {
            return
        }
        for simID in sortedSimIDs(in: sims) {
            guard let sim = sims[simID] else {
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
            guard evaluation.motives != sim.motives else {
                continue
            }
            sims[simID] = replacing(sim, motives: evaluation.motives)
            events.append(.motivesChanged(simID: simID, motives: evaluation.motives))
        }
    }

    private func selectAutonomousInteractions(
        for sims: inout [SimID: SimStateData],
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
                    guard try eligibility(for: offer, sim: sim, sims: sims, location: location)
                            .isEligible,
                          canReachItem(for: sim, offer: offer, simID: simID, sims: sims)
                    else {
                        continue
                    }
                    eligibleOffers.append(offer)
                }
            }

            let ranking = try AutonomyScoringSystem.rank(eligibleOffers, for: sim.motives)
            guard let offer = ranking.selectedOffer?.offer else {
                continue
            }
            let action = InteractionActionSystem.start(offer, initiatedBy: .autonomy)
            sims[simID] = replacingAction(sim, with: action)
            events.append(.actionChanged(simID: simID, action: action))
        }
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
        position: GridPosition? = nil
    ) -> SimStateData {
        SimStateData(
            id: sim.id,
            motives: motives ?? sim.motives,
            posture: sim.posture,
            currentLotID: sim.currentLotID,
            position: position ?? sim.position,
            activeAction: sim.activeAction
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
            activeAction: activeAction
        )
    }
}

private struct PlacedItemLocation: Sendable {
    let lotID: LotID
    let item: PlacedItem
    let definition: ItemDefinition
}
