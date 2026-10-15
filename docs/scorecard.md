# Motive Engine scorecard

Maintained by hand until a generator checks it in CI (planned in Akita; see
the [roadmap](./ROADMAP.md)). Every status below was verified against the
code and tests on 2026-10-14: each note names the source file or test that
proves it. Numbers here supersede estimates elsewhere.

When a change affects a row, update its status and evidence in the same
pull request. Statuses are `done`, `partial`, and `missing`.

## Summary

| Area | Done | Partial | Missing | Key numbers |
|---|---:|---:|---:|---|
| [Performance](#performance) | 4 | 0 | 4 | 4 benchmarks, all within budget; 4 scenarios not benchmarked yet (baseline 2026-10-14) |
| [Simulation core](#simulation-core) | 10 | 1 | 3 | |
| [Buffs](#buffs) | 5 | 0 | 0 | |
| [Scripting](#scripting) | 7 | 0 | 1 | 100,000-instruction and 256-call limits |
| [Content packs](#content-packs) | 7 | 0 | 2 | pack format 1 |
| [Wants and fears](#wants-and-fears) | 8 | 0 | 1 | |
| [Reliability](#reliability) | 4 | 1 | 1 | 0 force unwraps, `try!`, `fatalError`, or `precondition` in `Sources/` |
| [Documentation and schemas](#documentation-and-schemas) | 3 | 0 | 1 | 4 schemas, all with decoded examples |
| [Distribution](#distribution) | 3 | 0 | 2 | CI on macOS only |
| [Known issues](#known-issues) | | | | 6 open |

`swift test` passed all 171 tests across both libraries on 2026-10-14.

## Performance

Budgets are p95 limits for one workload run. The benchmark executable warms
each workload once, then times 30 samples; fixture setup is outside the
timed region. Run it with:

```sh
swift run -c release MotiveEngineBenchmarks
```

It exits with an error when a workload breaks its budget. CI doesn't run it
yet, so budgets are only checked when someone runs it locally.

Baseline: 2026-10-14, Swift 6.3.3, release configuration, Linux x86_64
(Bazzite, kernel 7.2.9). Not a pinned machine: compare changes on the same
host.

| Id | Workload | Budget (p95) | p50 ms | p95 ms | Status |
|---|---|---:|---:|---:|---|
| P1 | Decay 10,000 complete motive snapshots over one simulated second | 50 ms | 24.84 | 26.10 | within budget |
| P2 | Evaluate eligibility for 10,000 offers | 50 ms | 0.72 | 0.93 | within budget |
| P3 | Rank 1,000 eligible offers for one Sim | 25 ms | 1.13 | 1.42 | within budget |
| P4 | Tokenize and compile a 10,001-token Robusta program | 100 ms | 18.15 | 23.70 | within budget |

**Not benchmarked yet.** These paths exist but have no benchmark, so no
number is recorded. Budgets are proposals until a first measurement.

| Id | Scenario | Proposed budget | Why not yet |
|---|---|---:|---|
| P5 | One session step with 100 Sims and 200 items | 16 ms | no session benchmark fixture |
| P6 | Load and compose 50 packs with 2,000 items | 500 ms | no generated pack corpus |
| P7 | Start 1,000 scripted actions | 50 ms | no session benchmark fixture |
| P8 | Reroll wants and fears for 100 Sims | 10 ms | SWAF has no benchmark target |

## Simulation core

| Id | Target | Status | Evidence |
|---|---|---|---|
| CORE-1 | Motive snapshots and decay rates are complete, finite, and clamped to 0–100 | done | `Motives.swift`; `requiresEveryMotiveAndClampsFiniteLevels`, `requiresFiniteNonnegativeDecayRateForEveryMotive`, `rejectsMissingAndNonFiniteMotiveLevels` |
| CORE-2 | Decay and fulfillment are pure, clamped transformations | done | `decayAndFulfillmentReturnClampedNewValues`, `finiteExtremeRatesAndSignalsSaturateAtBounds`, `rejectsInvalidElapsedTimeAndNonFiniteSignals` |
| CORE-3 | Item definitions are separate from placed instances | done | `definitionCatalogAndPlacedInstancesUseDifferentIDs` |
| CORE-4 | Interaction content is validated: names, durations, strengths, duplicate IDs, capacity | done | `interactionDefinitionsRejectInvalidContent`, `catalogRejectsDuplicateDefinitionIDs`, `catalogRejectsDuplicateInteractionIDsWithinADefinition`, `itemDefinitionsRejectNonpositiveInteractionCapacity` |
| CORE-5 | Eligibility reports every unmet requirement in a stable order, including capacity edges | done | `eligibilityReportsEveryUnmetRequirementInStableOrder`, `eligibilityAllowsAvailableActorAndItemAtCapacityBoundary`, `zeroCapacityAndOverCapacityItemsAreUnavailable`, `missingEligibilitySnapshotsAreReported` |
| CORE-6 | Free will scores by urgency, breaks ties by stable ID, and picks nothing when nothing helps | done | `autonomyScoresAdvertisedBenefitsByCurrentMotiveUrgency`, `autonomyRankingUsesStableIDsForTiesAndRejectsNonPositiveChoices`, `autonomyScoringReportsOverflowInsteadOfReturningInvalidScores` |
| CORE-7 | Actions start, progress, complete, and stop without undoing applied effects | done | `actionProgressAppliesEffectsAndCompletesAtConfiguredDuration`, `actionInterruptionAndFailurePreservePriorProgressAndEffects`, `actionProgressRejectsInvalidElapsedTime` |
| CORE-8 | World state validates IDs, references, households, positions, and occupancy | done | `simulationStateRejectsMissingAndDuplicateReferences`, `simulationStateValidatesSimPositionsAndUniqueOccupancy`, `lotStateValidatesGridBoundsAndUniqueItemIDs`, `simulationEntitiesRejectDuplicateIDsAndHouseholdMembers` |
| CORE-9 | The session runs every phase in the declared order and reserves capacity | done | `standardSimulationPhaseOrderMatchesTheDeclaredWriteSequence`, `simulationSessionRoutesThenExecutesRequestedInteraction`, `simulationSessionReservesItemCapacityAndRollsBackInvalidCommands` |
| CORE-10 | Routing avoids blocking items and Sims, and waits when approaches are temporarily full | done | `interactionRoutingAvoidsBlockedAndOccupiedPositions`, `interactionRoutingReportsNoFreeApproachTile`, `simulationSessionWaitsWhenSimsBlockEveryApproachTile` |
| CORE-11 | Sims interact with each other, with relationships | missing | No Sim-to-Sim offers or relationship state; lot files' `relationship` field is ignored (Yamanote) |
| CORE-12 | A game in progress saves and restores, including running actions | partial | `ContentHealth` is `Codable` (`healthSurvivesASaveAndRejectsTamperedValues`); `SimulationState` is not, and `InteractionActionState` has no public initializer (Sobu) |
| CORE-13 | The world changes while running: items placed or removed, Sims arriving, leaving, or changing lots | missing | `SimulationSession` has no commands for these; a game must build a new session (Sobu) |
| CORE-14 | Posture changes and sleep | missing | `SimPosture` exists but the session never changes it; sleep tracking in `Household.swift` is internal and unused by the session (Joban) |

## Buffs

| Id | Target | Status | Evidence |
|---|---|---|---|
| BUFF-1 | Rule sets reject duplicate IDs and run rules in ID order | done | `ruleSetsRejectDuplicateIDsAndSortRulesByID` |
| BUFF-2 | Evaluation is pure, sums before clamping, and changes nothing over zero time | done | `evaluationOrdersEffectsByIDAndSumsBeforeClamping`, `evaluationIsRepeatableAndZeroTimeLeavesMotivesUnchanged`, `evaluationRejectsInvalidTimeAndNonFiniteSignals` |
| BUFF-3 | Ambient buffs reach Sims on the same lot within a radius, including hybrid items | done | `ambientRuleAppliesNearbyAmbientItemsOnTheSimsLot`, `ambientRuleIncludesHybridItemsAndOrdersByInstanceID`, `ambientRuleIgnoresSimsWithoutALotOrPosition`, `ambientRuleRejectsNegativeRadiusAndUnknownDefinitions` |
| BUFF-4 | The session applies buffs after decay, and changes nothing without them | done | `sessionAppliesBuffsAfterMotiveDecay`, `sessionWithoutBuffsEmitsNoBuffEvents`, `emptyAndInertBuffRulesMatchASessionWithoutBuffs` |
| BUFF-5 | Timed buffs apply only for their remaining time, restart without stacking, and expire with an event | done | `timedBuffsApplyOnlyForTheirRemainingTime`, `sessionAppliesRestartsAndExpiresTimedBuffs`, `timedBuffsRejectInvalidDurations`, `timedBuffCommandsAndStateAreValidated` |

## Scripting

| Id | Target | Status | Evidence |
|---|---|---|---|
| SCRIPT-1 | The lexer handles every token kind and reports errors with line numbers | done | `LexerTests.swift`: 13 tests, including `unterminatedStringThrows` and `unrecognizedCharacterThrows` |
| SCRIPT-2 | Source, syntax tree, and JSON IR run identically; malformed IR is rejected | done | `supportsAllPipelineRunEntryPoints`, `roundTripsMutableAndNestedInstructions`, `rejectsUnknownInstructions`, `rejectsUnexpectedOperands` |
| SCRIPT-3 | Language semantics: references, Bool and Trilean logic, `match`, `try`, states | done | `aliasesShareTheReferencedValue`, `keepsBooleanAndTrileanLogicSeparate`, `runsMatchAndTryCatch`, `transitionsBetweenStates`, `rejectsUnknownStateTransition` |
| SCRIPT-4 | Runaway scripts stop at the instruction and call-depth limits | done | `runtimeFailuresPropagateWithoutPartialEffects` (instruction limit), `stopsUnboundedRecursionAtTheCallDepthLimit` (256-call limit, with shallow recursion still working) |
| SCRIPT-5 | Interaction scripts read declared, read-only inputs and report effects only through `effect.fulfill` | done | `scriptsReadDeclaredInputsAndReportEffects`, `everyMotiveIsAvailableAsAnInput`, `scriptsCannotRedeclareInputsOrHostFunctions` |
| SCRIPT-6 | Invalid effects are rejected at load when literal, and at run time otherwise | done | `invalidLiteralEffectsAreRejectedWhenLoaded`, `invalidComputedEffectsAreRejectedWhenRun`, `computedArgumentsAreAcceptedWhenLoaded` |
| SCRIPT-7 | The session runs scripts when actions start; a failure fails only that action | done | `ScriptedSessionTests.swift`: `scriptEffectsReplaceWrittenEffectsAndStayFixedForTheAction`, `autonomyReportsAFailedScriptAndChoosesTheNextUsefulOffer`, `invalidRuntimeEffectsAreReportedAsTypedFailures` |
| SCRIPT-8 | Runtime errors report the source line | missing | The JSON IR carries no line information (Yamagata Phase 5) |

## Content packs

| Id | Target | Status | Evidence |
|---|---|---|---|
| PACK-1 | Manifests validate IDs, names, format, dependencies, and overrides | done | `packIDsRejectSeparatorsAndWhitespace`, `manifestsDecodeWithDefaults`, `manifestsRejectInvalidValues` |
| PACK-2 | Packs load items and compile scripts, reporting each bad file with its path | done | `packsLoadManifestItemsAndScripts`, `packsWithoutItemsLoadEmpty`, `invalidFilesAreReportedWithTheirPath` |
| PACK-3 | Unpacked folders load, and no path or symbolic link can leave the pack | done | `unpackedFoldersLoadThroughTheDirectorySource`, `directorySourcesRejectPathsOutsideThePack`, `directorySourcesRejectLinksThatLeaveThePack` |
| PACK-4 | Composition orders packs after dependencies, namespaces IDs, and rejects broken sets | done | `compositionQualifiesIDsAndOrdersDependenciesFirst`, `compositionRejectsBrokenPackSets` |
| PACK-5 | Overrides must be declared and come from dependencies; conflicts are reported | done | `declaredOverridesReplaceDependencyContent`, `invalidOverridesAreRejected`, `competingOverridesUseTheLatestPackAndReportTheConflict` |
| PACK-6 | Failing scripts escalate: cooldown, fallback, disabled interaction, disabled pack and dependents | done | `ContentHealthTests.swift`: `failingScriptsCoolDownThenFallBackToWrittenEffects`, `scriptOnlyInteractionsAreDisabledAndCommandsRejected`, `repeatedBreakageDisablesThePackAndItsDependents`, `enablingAPackRestoresItsDependentsAndInteractions` |
| PACK-7 | Content health saves and restores; tampered values are rejected | done | `healthSurvivesASaveAndRejectsTamperedValues` |
| PACK-8 | A packed format for distributing packs | missing | Format not chosen yet (Yamagata Phase 4) |
| PACK-9 | Wants and fears load from packs | missing | `MotiveEngineSWAF` reads only standalone JSON (Nishi-Kyushu) |

## Wants and fears

| Id | Target | Status | Evidence |
|---|---|---|---|
| SWAF-1 | Catalogs decode every trigger form and reject invalid content | done | `catalogDecodesEveryTriggerAndWeight`, `catalogRejectsInvalidContent`, `schemaExampleDecodes` |
| SWAF-2 | Rolls are seeded and weighted by tags and motive urgency | done | `rerollIsRepeatableForASeedAndFillsEachSlotOnce`, `rollWeightCombinesTagsAndMotiveUrgency`, `tiredSimsRollTheSleepWant` |
| SWAF-3 | Entries are fulfilled by interactions, low motives, game events, or directly | done | `completedInteractionsFulfillWantsAndRerollThatSlot`, `realizedFearsLowerAspirationAndRewardPointsWithoutGoingNegative`, `gameEventsAndDirectFulfillmentUseTheSameRules` |
| SWAF-4 | Aspiration and reward points stay in range; untracked Sims still earn points | done | `untrackedSimsEarnPointsWithoutMovingTheBar`, `aspirationDecaysAndRejectsInvalidInput` |
| SWAF-5 | Locked entries survive rerolls, including when slots shrink | done | `lockedEntriesSurviveRerollsUntilFulfilled`, `lockedEntriesAreKeptWhenSlotsShrink` |
| SWAF-6 | Wish mode: promises, expiring offers, cancellation | done | `wishModeFulfillsOnlyPromisedEntries`, `unpromisedOffersExpireAndLeaveTheirSlotEmpty`, `cancelRemovesPromisedAndOfferedEntries` |
| SWAF-7 | Fulfilled wishes grant a timed buff through session commands | done | `fulfilledWishesGrantTheFulfillmentBuff`, `fulfillmentBuffCommandsDriveTheSession` |
| SWAF-8 | Wants targeting a specific Sim or item; lifetime wants | missing | Nishi-Kyushu |
| SWAF-9 | SWAF ships separately and uses only the core's public API | done | `Package.swift`: the `MotiveEngineSWAF` target depends only on `MotiveEngine`, so the compiler enforces the boundary |

## Reliability

| Id | Target | Status | Evidence |
|---|---|---|---|
| REL-1 | No force unwraps, `try!`, `fatalError`, or `precondition` in library code | done | Searched `Sources/` on 2026-10-14: none. Not yet enforced automatically (REL-6) |
| REL-2 | Invalid input is reported as typed errors where it enters the engine | done | Validation tests in every area above; content errors carry the file path (`invalidFilesAreReportedWithTheirPath`) |
| REL-3 | Results are deterministic | done | `rerollIsRepeatableForASeedAndFillsEachSlotOnce`, `evaluationIsRepeatableAndZeroTimeLeavesMotivesUnchanged`, `simulationSnapshotOrdersTopLevelEntitiesByStableID`, `emptyAndInertBuffRulesMatchASessionWithoutBuffs` |
| REL-4 | A failed step leaves the session unchanged | done | `simulationSessionReservesItemCapacityAndRollsBackInvalidCommands`, `timedBuffCommandsAndStateAreValidated` |
| REL-5 | Hostile content can't hang the engine or read outside its pack | partial | Instruction limit and path and link checks are tested; the lexer, parser, and decoders are not fuzzed |
| REL-6 | A lint enforces REL-1 in CI | missing | Checked by hand only |

## Documentation and schemas

| Id | Target | Status | Evidence |
|---|---|---|---|
| DOC-1 | Every public declaration has a documentation comment | done | Checked across `Sources/` on 2026-10-14 |
| DOC-2 | Every content file has a schema whose example is decoded by a test | done | `schemaExamplesLoadAndCompose` (`pack.json`, `pack-items.json`), `schemaExampleDecodes` (`swaf.json`), `legacySchemaExamplesDecode` (`items.json`) |
| DOC-3 | Schemas are checked by a JSON Schema validator | missing | Tests decode examples with the engine only |
| DOC-4 | Architecture, modding, and contributor guides match the code | done | Reviewed 2026-10-14 |

## Distribution

| Id | Target | Status | Evidence |
|---|---|---|---|
| DIST-1 | Swift Package Manager products `MotiveEngine` and `MotiveEngineSWAF` | done | `Package.swift` |
| DIST-2 | CI builds and tests every push and pull request to `main` | done | `.github/workflows/swift.yml` (macOS) |
| DIST-3 | CI also builds and tests on Linux | missing | CI runs on macOS only; Linux is tested locally |
| DIST-4 | Release archives are built from `rel/*` and `release/*` after tests pass | done | `.github/workflows/release.yml` |
| DIST-5 | CI runs the benchmarks and checks this scorecard | missing | Removed from CI; planned in Akita |

## Known issues

| Id | Issue | Status | Note |
|---|---|---|---|
| BUG-1 | A file could be swapped between `DirectoryContentSource`'s link check and its read | accepted | Closing it needs lower-level file handling; acceptable for mod folders |
| BUG-2 | One Sim's state-specific script failures count toward disabling the script for every Sim | accepted | By design; the threshold and reset on success soften it |
| BUG-3 | A disabled pack's overrides leave the original item inert until the game recomposes | accepted | By design; recomposing without the pack restores the original |
| BUG-4 | The legacy item decoder (`Item`) skips unknown motive names silently | open | Content packs reject them; the legacy lot format doesn't |
| BUG-5 | Enabling a pack that isn't disabled still clears its interactions' history and reports `packEnabled` | open | Owner decision: keep as a reset, or make it a no-op |
| BUG-6 | The manifest's `version` and `format` field names | deferred | Owner decision pending |
