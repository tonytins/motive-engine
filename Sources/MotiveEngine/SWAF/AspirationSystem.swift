/// A fact reported by the aspiration system.
public enum AspirationEvent: Equatable, Sendable {
    /// Every unlocked slot was rerolled.
    case boardRerolled(simID: SimID)

    /// A want was fulfilled. Changes are the amounts actually applied.
    case wantFulfilled(
        simID: SimID,
        wantFearID: WantFearID,
        aspirationChange: Double,
        rewardPointChange: Int
    )

    /// A fear was realized. Changes are the amounts actually applied.
    case fearRealized(
        simID: SimID,
        wantFearID: WantFearID,
        aspirationChange: Double,
        rewardPointChange: Int
    )
}

/// The state and ordered events produced by one aspiration operation.
public struct AspirationUpdate: Equatable, Sendable {
    /// The resulting aspiration state.
    public let state: AspirationState

    /// Facts produced by the operation, in order.
    public let events: [AspirationEvent]
}

/// Pure operations over one Sim's wants and fears.
///
/// The system reads motives and simulation events but never changes them.
/// Every operation returns a new state; on error, nothing changes.
public enum AspirationSystem {
    /// Rerolls every unlocked slot.
    ///
    /// Locked entries keep their positions and are kept even when the
    /// profile has fewer slots than locked entries. Remaining slots are
    /// filled by weighted draws without repeats, using each definition's
    /// `rollWeight`. Slots stay empty when no eligible entries remain.
    public static func reroll(
        _ state: AspirationState,
        catalog: WantFearCatalog,
        motives: MotiveLevels
    ) throws -> AspirationUpdate {
        var next = state
        for kind in [WantFearKind.want, .fear] {
            let locked = state.slots(for: kind).filter(\.isLocked)
            for slot in locked {
                _ = try definition(for: slot, of: kind, in: catalog)
            }
            var slots = locked
            let capacity = kind == .want ? state.profile.wantSlots : state.profile.fearSlots
            while slots.count < capacity,
                  let rolled = roll(kind, excluding: slots, in: &next, catalog: catalog, motives: motives)
            {
                slots.append(WantFearSlot(definitionID: rolled))
            }
            next.setSlots(slots, for: kind)
        }
        return AspirationUpdate(state: next, events: [.boardRerolled(simID: state.simID)])
    }

    /// Fulfills entries triggered by simulation events or current motives.
    ///
    /// Interaction triggers match `actionChanged` events for this Sim whose
    /// action completed. Motive triggers compare against `motives`, the
    /// Sim's current levels. Each fulfilled slot is rerolled once, and never
    /// to the entry that was just fulfilled.
    public static func observe(
        _ state: AspirationState,
        events: [SimulationEvent],
        catalog: WantFearCatalog,
        motives: MotiveLevels
    ) throws -> AspirationUpdate {
        let completedOffers = events.compactMap { event -> InteractionOffer? in
            guard case let .actionChanged(simID, action) = event,
                  simID == state.simID,
                  action.status == .completed
            else {
                return nil
            }
            return action.offer
        }

        return try fulfill(state, catalog: catalog, motives: motives) { definition in
            switch definition.trigger {
            case .gameEvent:
                return false
            case let .interactionCompleted(itemDefinitionID, interactionDefinitionID):
                return completedOffers.contains { offer in
                    (itemDefinitionID.map { $0 == offer.itemDefinitionID } ?? true)
                        && (interactionDefinitionID.map { $0 == offer.interactionDefinitionID } ?? true)
                }
            case let .motiveBelow(motiveType, level):
                return motives.level(for: motiveType) < level
            }
        }
    }

    /// Fulfills entries triggered by a game-reported event.
    public static func report(
        _ gameEvent: GameEventID,
        to state: AspirationState,
        catalog: WantFearCatalog,
        motives: MotiveLevels
    ) throws -> AspirationUpdate {
        try fulfill(state, catalog: catalog, motives: motives) {
            $0.trigger == .gameEvent(gameEvent)
        }
    }

    /// Fulfills one entry on the board regardless of its trigger.
    ///
    /// - Throws: `AspirationError.notOnBoard` if the entry is not shown.
    public static func fulfill(
        _ id: WantFearID,
        in state: AspirationState,
        catalog: WantFearCatalog,
        motives: MotiveLevels
    ) throws -> AspirationUpdate {
        guard (state.wants + state.fears).contains(where: { $0.definitionID == id }) else {
            throw AspirationError.notOnBoard(id)
        }
        return try fulfill(state, catalog: catalog, motives: motives) { $0.id == id }
    }

    /// Locks an entry so rerolls keep it until it is fulfilled.
    ///
    /// Locking an already locked entry changes nothing.
    ///
    /// - Throws: `AspirationError.notOnBoard` or `.lockLimitReached`.
    public static func lock(_ id: WantFearID, in state: AspirationState) throws -> AspirationState {
        try setLock(true, on: id, in: state)
    }

    /// Unlocks an entry so the next reroll can replace it.
    ///
    /// - Throws: `AspirationError.notOnBoard` if the entry is not shown.
    public static func unlock(_ id: WantFearID, in state: AspirationState) throws -> AspirationState {
        try setLock(false, on: id, in: state)
    }

    /// Lowers aspiration over time. Sims that do not track aspiration are unchanged.
    ///
    /// - Throws: `AspirationError.invalidDecay` for a negative or non-finite
    ///   rate or elapsed time.
    public static func decay(
        _ state: AspirationState,
        ratePerSecond: Double,
        overSeconds elapsedSeconds: Double
    ) throws -> AspirationState {
        guard ratePerSecond.isFinite, ratePerSecond >= 0,
              elapsedSeconds.isFinite, elapsedSeconds >= 0
        else {
            throw AspirationError.invalidDecay
        }
        guard state.profile.tracksAspiration else {
            return state
        }
        var next = state
        next.aspiration = clampedAspiration(state.aspiration - ratePerSecond * elapsedSeconds)
        return next
    }

    // MARK: - Fulfillment

    private static func fulfill(
        _ state: AspirationState,
        catalog: WantFearCatalog,
        motives: MotiveLevels,
        matching isTriggered: (WantFearDefinition) -> Bool
    ) throws -> AspirationUpdate {
        var next = state
        var events: [AspirationEvent] = []

        for kind in [WantFearKind.want, .fear] {
            let original = state.slots(for: kind)
            var fulfilledIndices: [Int] = []
            for (index, slot) in original.enumerated() {
                let definition = try definition(for: slot, of: kind, in: catalog)
                guard isTriggered(definition) else {
                    continue
                }
                fulfilledIndices.append(index)
                events.append(apply(definition, to: &next))
            }

            // Reroll only the fulfilled slots. Entries rolled here are not
            // checked again, and a fulfilled entry is not rolled straight back.
            var slots = original
            for index in fulfilledIndices.reversed() {
                slots.remove(at: index)
            }
            let fulfilled = fulfilledIndices.map { original[$0] }
            for index in fulfilledIndices {
                guard let rolled = roll(
                    kind,
                    excluding: slots + fulfilled,
                    in: &next,
                    catalog: catalog,
                    motives: motives
                ) else {
                    continue
                }
                slots.insert(WantFearSlot(definitionID: rolled), at: min(index, slots.count))
            }
            next.setSlots(slots, for: kind)
        }
        return AspirationUpdate(state: next, events: events)
    }

    private static func apply(
        _ definition: WantFearDefinition,
        to state: inout AspirationState
    ) -> AspirationEvent {
        let previousAspiration = state.aspiration
        let previousRewardPoints = state.rewardPoints
        switch definition.kind {
        case .want:
            if state.profile.tracksAspiration {
                state.aspiration = clampedAspiration(state.aspiration + definition.aspirationPoints)
            }
            let (sum, overflow) = state.rewardPoints.addingReportingOverflow(definition.rewardPoints)
            state.rewardPoints = overflow ? Int.max : sum
            return .wantFulfilled(
                simID: state.simID,
                wantFearID: definition.id,
                aspirationChange: state.aspiration - previousAspiration,
                rewardPointChange: state.rewardPoints - previousRewardPoints
            )
        case .fear:
            if state.profile.tracksAspiration {
                state.aspiration = clampedAspiration(state.aspiration - definition.aspirationPoints)
            }
            state.rewardPoints = max(0, state.rewardPoints - definition.rewardPoints)
            return .fearRealized(
                simID: state.simID,
                wantFearID: definition.id,
                aspirationChange: state.aspiration - previousAspiration,
                rewardPointChange: state.rewardPoints - previousRewardPoints
            )
        }
    }

    // MARK: - Rolling

    /// Draws one eligible definition not already on the board.
    ///
    /// Candidates are visited in ID order so a seed always gives the same result.
    private static func roll(
        _ kind: WantFearKind,
        excluding board: [WantFearSlot],
        in state: inout AspirationState,
        catalog: WantFearCatalog,
        motives: MotiveLevels
    ) -> WantFearID? {
        let shown = Set(board.map(\.definitionID))
        let candidates = catalog.definitions.compactMap { definition -> (WantFearID, Double)? in
            guard definition.kind == kind, !shown.contains(definition.id) else {
                return nil
            }
            let weight = definition.rollWeight(tags: state.profile.tags, motives: motives)
            return weight > 0 ? (definition.id, weight) : nil
        }
        let totalWeight = candidates.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0, totalWeight.isFinite else {
            return nil
        }

        var remaining = state.nextUnitInterval() * totalWeight
        for (id, weight) in candidates {
            remaining -= weight
            if remaining < 0 {
                return id
            }
        }
        return candidates.last?.0
    }

    private static func setLock(
        _ isLocked: Bool,
        on id: WantFearID,
        in state: AspirationState
    ) throws -> AspirationState {
        var next = state
        for kind in [WantFearKind.want, .fear] {
            var slots = state.slots(for: kind)
            guard let index = slots.firstIndex(where: { $0.definitionID == id }) else {
                continue
            }
            guard slots[index].isLocked != isLocked else {
                return state
            }
            if isLocked {
                let lockedCount = (state.wants + state.fears).count(where: \.isLocked)
                guard lockedCount < state.profile.lockLimit else {
                    throw AspirationError.lockLimitReached
                }
            }
            slots[index] = WantFearSlot(definitionID: id, isLocked: isLocked)
            next.setSlots(slots, for: kind)
            return next
        }
        throw AspirationError.notOnBoard(id)
    }

    private static func definition(
        for slot: WantFearSlot,
        of kind: WantFearKind,
        in catalog: WantFearCatalog
    ) throws -> WantFearDefinition {
        guard let definition = catalog.definition(for: slot.definitionID) else {
            throw AspirationError.missingDefinition(slot.definitionID)
        }
        guard definition.kind == kind else {
            throw AspirationError.kindMismatch(slot.definitionID)
        }
        return definition
    }

    private static func clampedAspiration(_ value: Double) -> Double {
        value.clamped(to: AspirationState.minimumAspiration ... AspirationState.maximumAspiration)
    }
}
