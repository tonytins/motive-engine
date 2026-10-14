/// Two or more packs override the same definition.
///
/// The pack latest in load order wins. Loading still succeeds; games can
/// show conflicts to the player.
public struct OverrideConflict: Equatable, Sendable {
    /// The overridden definition.
    public let definitionID: ItemDefinitionID

    /// Every pack that overrides it, in load order. The last one wins.
    public let packIDs: [ContentPackID]
}

/// Item content combined from several packs.
public struct ContentComposition: Sendable {
    /// Every definition, keyed by its qualified ID.
    public let catalog: ItemDefinitionCatalog

    /// Packs in the order they were applied.
    public let loadOrder: [ContentPackID]

    /// Definitions overridden by more than one pack, ordered by definition ID.
    public let conflicts: [OverrideConflict]

    private let ownersByDefinitionID: [ItemDefinitionID: ContentPackID]
    private let dependenciesByPackID: [ContentPackID: [ContentPackID]]

    init(
        catalog: ItemDefinitionCatalog,
        loadOrder: [ContentPackID],
        conflicts: [OverrideConflict],
        ownersByDefinitionID: [ItemDefinitionID: ContentPackID],
        dependenciesByPackID: [ContentPackID: [ContentPackID]]
    ) {
        self.catalog = catalog
        self.loadOrder = loadOrder
        self.conflicts = conflicts
        self.ownersByDefinitionID = ownersByDefinitionID
        self.dependenciesByPackID = dependenciesByPackID
    }

    /// The pack whose content is used for a definition, including overrides.
    public func owner(of definitionID: ItemDefinitionID) -> ContentPackID? {
        ownersByDefinitionID[definitionID]
    }

    /// The packs a pack declares as dependencies.
    public func dependencies(of packID: ContentPackID) -> [ContentPackID] {
        dependenciesByPackID[packID, default: []]
    }

    /// Every loaded pack that depends on `packID`, directly or indirectly, in load order.
    ///
    /// This walks the dependency graph and is O(packs × dependencies).
    public func dependents(of packID: ContentPackID) -> [ContentPackID] {
        var affected: Set<ContentPackID> = [packID]
        var result: [ContentPackID] = []
        for candidate in loadOrder
            where dependencies(of: candidate).contains(where: affected.contains)
        {
            affected.insert(candidate)
            result.append(candidate)
        }
        return result
    }
}

/// Combines content packs into one catalog.
public enum ContentComposer {
    /// Orders packs, qualifies their IDs, and applies overrides.
    ///
    /// Packs keep the order supplied, except that each pack moves after the
    /// packs it depends on. A definition written as `fridge` in pack `mod`
    /// becomes `mod:fridge`. A definition written with another pack's prefix,
    /// such as `base:fridge`, replaces that definition; the manifest must
    /// declare it as an override, and `base` must be a direct or indirect
    /// dependency. When several packs override one definition, the latest in
    /// load order wins and the conflict is reported.
    ///
    /// - Throws: `ContentPackError` for duplicate packs, missing dependencies,
    ///   dependency cycles, or invalid, undeclared, or unfulfilled overrides,
    ///   and `ItemDefinitionCatalogError` for duplicate definitions.
    public static func compose(_ packs: [ContentPack]) throws -> ContentComposition {
        let ordered = try loadOrder(of: packs)
        var definitionsByID: [ItemDefinitionID: ItemDefinition] = [:]
        var owners: [ItemDefinitionID: ContentPackID] = [:]
        var overridingPacks: [ItemDefinitionID: [ContentPackID]] = [:]
        let dependencies = transitiveDependencies(of: ordered)

        for pack in ordered {
            let packID = pack.manifest.id
            var defined: Set<ItemDefinitionID> = []
            for definition in pack.definitions {
                let qualifiedID: ItemDefinitionID
                if let targetPack = definition.id.packID {
                    qualifiedID = definition.id
                    guard pack.manifest.overrides.contains(qualifiedID) else {
                        throw ContentPackError.invalidOverride(packID, definitionID: qualifiedID)
                    }
                    guard dependencies[packID, default: []].contains(targetPack),
                          definitionsByID[qualifiedID] != nil
                    else {
                        throw ContentPackError.overrideTargetMissing(packID, definitionID: qualifiedID)
                    }
                    overridingPacks[qualifiedID, default: []].append(packID)
                } else {
                    // A `:` always marks an override, so a malformed prefix is invalid.
                    guard !definition.id.rawValue.contains(":"),
                          let id = ItemDefinitionID("\(packID.rawValue):\(definition.id.rawValue)")
                    else {
                        throw ContentPackError.invalidOverride(packID, definitionID: definition.id)
                    }
                    qualifiedID = id
                    guard definitionsByID[qualifiedID] == nil else {
                        throw ItemDefinitionCatalogError.duplicateDefinitionID(qualifiedID)
                    }
                }
                guard defined.insert(qualifiedID).inserted else {
                    throw ItemDefinitionCatalogError.duplicateDefinitionID(qualifiedID)
                }
                definitionsByID[qualifiedID] = try ItemDefinition(
                    id: qualifiedID,
                    identity: definition.identity,
                    signals: definition.signals,
                    interactions: definition.interactions,
                    interactionCapacity: definition.interactionCapacity
                )
                owners[qualifiedID] = packID
            }
            for definitionID in pack.manifest.overrides where !defined.contains(definitionID) {
                throw ContentPackError.overrideNotDefined(packID, definitionID: definitionID)
            }
        }

        let conflicts = overridingPacks
            .filter { $0.value.count > 1 }
            .map { OverrideConflict(definitionID: $0.key, packIDs: $0.value) }
            .sorted { $0.definitionID.rawValue < $1.definitionID.rawValue }
        return ContentComposition(
            catalog: try ItemDefinitionCatalog(definitions: Array(definitionsByID.values)),
            loadOrder: ordered.map(\.manifest.id),
            conflicts: conflicts,
            ownersByDefinitionID: owners,
            dependenciesByPackID: Dictionary(uniqueKeysWithValues: ordered.map {
                ($0.manifest.id, $0.manifest.dependencies)
            })
        )
    }

    /// Keeps the supplied order but places every pack after its dependencies.
    private static func loadOrder(of packs: [ContentPack]) throws -> [ContentPack] {
        var packsByID: [ContentPackID: ContentPack] = [:]
        for pack in packs {
            guard packsByID.updateValue(pack, forKey: pack.manifest.id) == nil else {
                throw ContentPackError.duplicatePack(pack.manifest.id)
            }
        }
        for pack in packs {
            for dependency in pack.manifest.dependencies where packsByID[dependency] == nil {
                throw ContentPackError.missingDependency(pack.manifest.id, dependency: dependency)
            }
        }

        var ordered: [ContentPack] = []
        var placed: Set<ContentPackID> = []
        var remaining = packs
        while !remaining.isEmpty {
            guard let index = remaining.firstIndex(where: {
                $0.manifest.dependencies.allSatisfy(placed.contains)
            }) else {
                throw ContentPackError.dependencyCycle(remaining.map(\.manifest.id))
            }
            let pack = remaining.remove(at: index)
            ordered.append(pack)
            placed.insert(pack.manifest.id)
        }
        return ordered
    }

    /// Every pack each pack depends on, directly or indirectly.
    ///
    /// `packs` must already be in load order, so dependencies come first.
    private static func transitiveDependencies(
        of packs: [ContentPack]
    ) -> [ContentPackID: Set<ContentPackID>] {
        var result: [ContentPackID: Set<ContentPackID>] = [:]
        for pack in packs {
            var all = Set(pack.manifest.dependencies)
            for dependency in pack.manifest.dependencies {
                all.formUnion(result[dependency, default: []])
            }
            result[pack.manifest.id] = all
        }
        return result
    }
}
