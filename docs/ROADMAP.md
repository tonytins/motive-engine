# Motive Engine roadmap

> **Last reviewed:** 2026-10-14 · **Last updated:** 2026-10-14 · **Change:** minor (scorecard fixes: recursion-limit test and a self-contained legacy item schema; estimates unchanged) · **Stage:** pre-alpha

Forward-looking: where the engine stands, what blocks the next stage, and
what comes next. Measured numbers and verified checklists are in the
[scorecard](./scorecard.md); how the systems work is in the
[architecture overview](./architecture.md).

Keep it current: when work lands, update its milestone row and checklist,
re-estimate what remains, and add a line to the revision history.

Milestones through Nishi-Kyushu, plus Akita and Yamagata, are named after
Shinkansen routes. With those used up, later milestones are named after
regular JR lines. The names are labels, not claims about speed or release
dates. Estimates are rough hours for one developer and are
re-measured when a milestone lands.

## Alpha gate

Alpha means a game could use the engine for a basic needs-driven life
simulation: each core workflow below works end to end through the public
API. A row blocks alpha only when a game cannot complete that workflow at
all. Missing depth or a clumsy path is `partial, not blocking`, which makes
it a beta item.

| Core workflow | Works end to end? | Evidence | Hours to pass (est.) |
|---|---|---|---|
| Author and load content: items, interactions, scripts, mods | yes | Content packs with manifests, dependencies, overrides, and scripts compiled at load; broken scripts escalate instead of stopping the game | 0 |
| Build a world of Sims, households, and lots | yes | Validated `SimulationState` with stable IDs, positions, and occupancy | 0 |
| Run the simulation: free will, player commands, movement, actions | yes | `SimulationSession` with routing, capacity, buffs, and scripted effects; the NewbieHouse example | 0 |
| Observe what happened | yes | Ordered snapshots and typed events for every change | 0 |
| Sims socialize with each other | **no** | No Sim-to-Sim interactions or relationships. The `social` motive is filled only by items, and the `relationship` field in lot files is ignored | 35–70 |
| Save and reload a game in progress | partial, not blocking | Content health is `Codable`. World state can be rebuilt through public initializers but isn't `Codable`, and a Sim mid-interaction can't be restored | 8–15 |
| Change the world while it runs: build, buy, arrivals, departures | partial, not blocking | Possible only by building a new session from an edited state; no commands to place items, add Sims, or move Sims between lots | 12–25 |
| Daily rhythm: sleep and posture | partial, not blocking | A bed works as an energy item, but there is no day clock, sleep state, or posture change from chairs and beds | 20–40 |

**Result: pre-alpha.** Socializing is the only blocking row, about 35–70
hours of work (Yamanote). If socializing is deliberately left out of alpha, the
engine is alpha today and the three partial rows are the first beta items.
That scope call belongs to the owner.

## Current focus

In order:

1. **Decide whether socializing is in alpha scope**, then start Yamanote or
   move to beta work.
2. **Finish Yamagata:** choose the packed pack format (Phase 4) and report
   source lines in script errors (Phase 5).
3. **Make games saveable** (Sobu): `Codable` world state and restorable
   actions.
4. **Measure the session** (Akita): benchmark a full step, pack loading, and
   script runs, then generate and check the scorecard in CI.

Deferred by the owner: the naming of the manifest's `version` and `format`
fields, and the packed pack format, which is decided in Yamagata Phase 4.

## Milestones

"Done" is the share of the milestone's checklist below that is complete.
"Remaining" estimates the open items only.

| Route | Milestone | Done | Remaining (h, est.) | Notes |
|---|---|---:|---:|---|
| Tokaido | Tested foundations | 100% | 0 | Motives, clamping, decay, release workflow |
| Sanyo | Content separate from instances | 100% | 0 | Definition and instance IDs, catalog, content packs |
| Tohoku | Interaction offers | 86% | 6–12 | Missing: offers that depend on context beyond posture |
| Hokuriku | Eligibility | 80% | 6–12 | Missing: requirements on actor state, item state, and availability |
| Joetsu | Free will | 100% | 0 | Urgency scoring, stable ties, usefulness cutoff |
| Kyushu | Action execution | 100% | 0 | Start, progress, completion, interruption, failure |
| Hokkaido | Simulation phases | 100% | 0 | World state, phase order, routing, capacity, session |
| Nishi-Kyushu | Optional extensions | 80% | 19–38 | Buffs, scripts in the session, SWAF with wish mode. Missing: targeted and lifetime wants; wants and fears in packs |
| Akita | Measure before optimizing | 33% | 10–20 | Four benchmarks. Missing: session benchmarks, scorecard in CI; storage changes only if measured |
| Yamagata | Content packs, safely | 60% | 14–32 | Packs and script health done. Missing: packed format, script line numbers |
| Yamanote | Sims together | 0% | 35–70 | Sim-to-Sim interactions and relationships |
| Sobu | Save and change the world | 0% | 20–40 | `Codable` state, restorable actions, editing a running world |
| Joban | Daily life | 0% | 20–40 | Day clock, sleep, posture changes |
| | **Total** | | **≈ 130–264** | |

## Upcoming work, ranked

| Rank | Work | Milestone | Estimate (h) |
|---|---|---|---|
| 1 | Sim-to-Sim interactions and relationships | Yamanote | 35–70 |
| 2 | Packed pack format and script line numbers | Yamagata | 14–32 |
| 3 | `Codable` world state and restorable actions | Sobu | 8–15 |
| 4 | Session benchmarks and the scorecard in CI | Akita | 10–20 |
| 5 | Editing a running world, moving Sims between lots | Sobu | 12–25 |
| 6 | Day clock, sleep, and posture | Joban | 20–40 |
| 7 | Targeted and lifetime wants; wants and fears in packs | Nishi-Kyushu | 19–38 |
| 8 | Contextual offers and broader eligibility | Tohoku, Hokuriku | 12–24 |

Beta needs ranks 1–6 in substance, about 100–200 hours.

## Milestone checklists

### Tokaido: Tested foundations

- [x] Keep the core render-agnostic and document the architecture.
- [x] Add a public `/docs` entry point and architecture overview.
- [x] Expose complete, validated motive snapshots and decay-rate tables.
- [x] Apply motive decay and fulfillment as pure transformations.
- [x] Test bounds, invalid input, clamping, and lowest-motive ties.
- [x] Correct grid bounds, ambient detection, and household sleep tracking.
- [x] Release archives from `rel/*` and `release/*` after `swift test`.

### Sanyo: Content separate from instances

- [x] Stable, content-supplied definition and instance IDs.
- [x] Reusable item content separate from placed-item identity and position.
- [x] An indexed definition catalog that rejects duplicate IDs.
- [x] Several placed instances share one definition.
- [x] Catalog composition, overrides, and content loading, as content packs.

### Tohoku: Interaction offers

- [x] Reusable interaction definitions with stable IDs.
- [x] Advertised benefits kept separate from applied effects.
- [x] Instance-specific offers from a definition and a placed item.
- [x] Reject empty names, non-finite strengths, and duplicate interaction IDs.
- [x] Document offers as candidates, not proof of eligibility.
- [x] An optional required-posture requirement.
- [ ] Offers that depend on wider context as more requirements arrive.

### Hokuriku: Eligibility

- [x] Typed posture requirements and actor and item availability snapshots.
- [x] Capacity and occupancy as explicit snapshot data.
- [x] Explicit reasons when an offer is unavailable.
- [x] Tests without a running simulation.
- [ ] Requirements on actor state, item state, and interaction availability.

### Joetsu: Free will

- [x] Continuous motive urgency and a positive-score usefulness cutoff.
- [x] Score eligible offers from motives and advertised benefits.
- [x] Deterministic tie-breaking and a defined result when nothing is useful.
- [x] Explainable rankings that don't change simulation state.
- [x] Player commands and free will kept separate from execution.

### Kyushu: Action execution

- [x] Action state, progress, completion, interruption, and failure as values.
- [x] Effects applied by systems, separately from scoring.
- [x] Player commands and free will share one action model.
- [x] Transitions and effects tested with pure inputs and outputs.

### Hokkaido: Simulation phases

- [x] Validated Sim, lot, and household state keyed by stable IDs.
- [x] A declared phase order with data ownership and write order.
- [x] Deterministic snapshots and structured step events.
- [x] Routing to free tiles around blocking items and other Sims.
- [x] Item capacity, reserved by active actions.
- [x] A deterministic, value-type session coordinating every phase.
- [x] Concurrency kept outside the session.

### Nishi-Kyushu: Optional extensions

- [x] Buffs: inputs, outputs, timing, ordering, and idempotency.
- [x] Timed buffs, such as a "Fulfilled" mood after a wish.
- [x] Wants and fears (SWAF) as an optional extension.
- [x] SWAF shipped as the separate `MotiveEngineSWAF` product.
- [x] Sims 3-style wishes: promises, expiring offers, cancellation.
- [x] A typed boundary between Robusta and item interactions.
- [x] Interaction scripts run by the session when actions start.
- [x] Simulations work with every optional extension absent.
- [ ] Wants and fears that target a specific Sim or item, and lifetime wants
  with bonus points for related wishes.
- [ ] Wants and fears loaded from content packs, namespaced like items.

### Akita: Measure before optimizing

- [x] Benchmark representative workloads before changing storage.
- [ ] Benchmark a full session step, pack loading, script runs, and SWAF
  rolls; generate the scorecard and check it in CI.
- [ ] Consider batched or structure-of-arrays storage only if measurements
  justify it, preserving behavior and public types.

### Yamagata: Content packs, safely

- [x] Phase 1: typed script failures, and invalid `effect.fulfill` calls
  rejected at load when detectable.
- [x] Phase 2: content packs with manifests, dependencies, a game-supplied
  load order, namespaced IDs, declared overrides, reported conflicts, and
  unpacked folders read through a content source.
- [x] Phase 3: script health. Cooldowns, falling back to written effects,
  disabling interactions and packs with their dependents, saved health, and
  re-enabling by the player.
- [ ] Phase 4: choose and support a packed pack format.
- [ ] Phase 5: report source line numbers in Robusta runtime errors.

### Yamanote: Sims together

- [ ] Sims offer interactions to other Sims (the `sim` modifier).
- [ ] Two-party actions that occupy and affect both Sims.
- [ ] Relationships between Sims as validated, saveable state.
- [ ] The `social` motive filled by other Sims, scaled by relationship.

### Sobu: Save and change the world

- [ ] `Codable` world state, validated when decoded.
- [ ] Restorable running actions.
- [ ] Session commands to place and remove items and add and remove Sims.
- [ ] Moving Sims between lots.

### Joban: Daily life

- [ ] A simulated day clock.
- [ ] Sleep as a Sim state, with wake rules.
- [ ] Posture changes from chairs, beds, and toilets.

## Critical path

Tokaido through Hokkaido had to happen in order, and did. Everything after
builds on the session and can proceed in parallel, with two exceptions:
Sobu's restorable actions should follow Yamanote, because two-party actions
change what an action holds, and Akita's storage work waits for its own
measurements. The long poles are Yamanote and Joban.

## Risks most likely to push estimates up

- Two-party actions may need changes to the action model and to how
  capacity and routing work.
- Saving mid-action requires a stable, versioned save format before games
  depend on it.
- The packed pack format may need a dependency, depending on the choice.
- Session performance is unmeasured; a slow step could force storage work
  earlier than planned.
- Content health is shared by every Sim, so a script that fails only in
  rare states could still be disabled for everyone.
- Hostile mod content is checked at known boundaries, but nothing fuzzes
  the lexer, parser, or decoders yet.

## Revision history

| Date | Change | Summary |
|---|---|---|
| 2026-10-14 | minor | Scorecard SCRIPT-4 and DOC-2 done: a test for Robusta's call-depth limit, and `schema/items.json` made self-contained with examples the decoder accepts and a test that decodes them. Estimates unchanged. |
| 2026-10-14 | minor | Renamed Chuo, Shikoku, and San'in to Yamanote, Sobu, and Joban: later milestones use regular JR lines once the Shinkansen routes run out. Estimates unchanged. |
| 2026-10-14 | major | Rewritten with an alpha gate (pre-alpha: socializing blocks), estimates, ranked work, and three new milestones (Chuo, Shikoku, San'in) from gaps found while assessing the gate. Earlier history is in git. |
