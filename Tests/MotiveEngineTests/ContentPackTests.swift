import Foundation
import MotiveEngine
import Testing

private func manifest(
    _ id: String,
    dependencies: [String] = [],
    overrides: [String] = []
) -> String {
    let dependencyList = dependencies.map { #""\#($0)""# }.joined(separator: ",")
    let overrideList = overrides.map { #""\#($0)""# }.joined(separator: ",")
    return #"""
    {"id": "\#(id)", "name": "\#(id) pack", "version": 1,
     "dependencies": [\#(dependencyList)], "overrides": [\#(overrideList)]}
    """#
}

/// One item with a single interaction restoring `motive`.
private func items(_ entries: [(id: String, motive: String)]) -> String {
    let items = entries.map { entry in
        #"""
        {"id": "\#(entry.id)", "name": "\#(entry.id)", "modifiers": ["appliance"],
         "interactions": [{"id": "use", "name": "Use", "duration": 10,
                           "advertises": {"\#(entry.motive)": 2}, "effects": {"\#(entry.motive)": 2}}]}
        """#
    }
    return #"{"items": [\#(items.joined(separator: ","))]}"#
}

private func pack(_ files: [String: String]) throws -> ContentPack {
    try ContentPack(loadingFrom: MemorySource(files: files))
}

private func id(_ rawValue: String) throws -> ItemDefinitionID {
    try #require(ItemDefinitionID(rawValue))
}

private func packID(_ rawValue: String) throws -> ContentPackID {
    try #require(ContentPackID(rawValue))
}

@Suite("Content packs")
struct ContentPackTests {
    // MARK: Manifests

    @Test(arguments: ["", "base:core", "my mod", "tab\tid"])
    func packIDsRejectSeparatorsAndWhitespace(rawValue: String) {
        #expect(ContentPackID(rawValue) == nil)
    }

    @Test func manifestsDecodeWithDefaults() throws {
        let decoded = try ContentPackManifest(jsonData: Data(
            #"{"id": "base", "name": "Base Game", "version": 1}"#.utf8
        ))

        #expect(decoded.id == (try packID("base")))
        #expect(decoded.dependencies.isEmpty)
        #expect(decoded.overrides.isEmpty)
    }

    @Test func manifestsRejectInvalidValues() throws {
        let base = try packID("base")
        #expect(throws: ContentPackError.unsupportedVersion(base, version: 2)) {
            try ContentPackManifest(id: base, name: "Base", version: 2)
        }
        #expect(throws: DecodingError.self) {
            try ContentPackManifest(jsonData: Data(#"{"id": "base", "name": "Base", "version": "1.0"}"#.utf8))
        }
        #expect(throws: ContentPackError.self) {
            try ContentPackManifest(id: base, name: "", version: 1)
        }
        #expect(throws: ContentPackError.self) {
            try ContentPackManifest(id: base, name: "Base", version: 1, dependencies: [base])
        }
        #expect(throws: ContentPackError.self) {
            try ContentPackManifest(id: base, name: "Base", version: 1, dependencies: [packID("a"), packID("a")])
        }
        #expect(throws: ContentPackError.invalidOverride(base, definitionID: try id("fridge"))) {
            try ContentPackManifest(id: base, name: "Base", version: 1, overrides: [id("fridge")])
        }
        #expect(throws: ContentPackError.invalidOverride(base, definitionID: try id("base:fridge"))) {
            try ContentPackManifest(id: base, name: "Base", version: 1, overrides: [id("base:fridge")])
        }
    }

    // MARK: Loading

    @Test func packsLoadManifestItemsAndScripts() throws {
        let loaded = try pack([
            "pack.json": manifest("base"),
            "items.json": #"""
            {"items": [{"id": "fridge", "name": "Fridge", "modifiers": ["appliance"], "capacity": 2,
              "signals": {"fun": 0.5},
              "interactions": [{"id": "eat", "name": "Eat", "duration": 20, "posture": "standing",
                                "advertises": {"hunger": 2}, "script": "eat"}]}]}
            """#,
            "scripts/eat.rob": """
            state default
                func stateEntry()
                    effect.fulfill("hunger", 3)
                end
            end
            """,
        ])

        let fridge = try #require(loaded.definitions.first)
        let eat = try #require(fridge.interactions.first)
        #expect(loaded.manifest.id == (try packID("base")))
        #expect(fridge.id == (try id("fridge")))
        #expect(fridge.interactionCapacity == 2)
        #expect(fridge.signals == [MotiveSignal(motiveType: .fun, strengthPerSecond: 0.5)])
        #expect(eat.advertisedBenefits == [MotiveBenefit(motiveType: .hunger, expectedStrengthPerSecond: 2)])
        #expect(eat.motiveEffects.isEmpty)
        #expect(eat.requirements.requiredPosture == .standing)
        #expect(eat.script != nil)
    }

    @Test func packsWithoutItemsLoadEmpty() throws {
        #expect(try pack(["pack.json": manifest("empty")]).definitions.isEmpty)
    }

    @Test(arguments: [
        ([:], "pack.json"),
        (["pack.json": "{"], "pack.json"),
        (["items.json": "{"], "items.json"),
        (["items.json": items([("fridge", "thirst")])], "items.json"),
        (["items.json": #"{"items": [{"id": "x", "name": "X", "modifiers": [], "interactions": [{"id": "a", "name": "A", "duration": 1, "script": "missing"}]}]}"#], "scripts/missing.rob"),
        (["items.json": #"{"items": [{"id": "x", "name": "X", "modifiers": [], "interactions": [{"id": "a", "name": "A", "duration": 1, "script": "bad"}]}]}"#, "scripts/bad.rob": "state default"], "scripts/bad.rob"),
    ])
    func invalidFilesAreReportedWithTheirPath(files: [String: String], expectedPath: String) throws {
        var allFiles = files
        if allFiles["pack.json"] == nil, expectedPath != "pack.json" {
            allFiles["pack.json"] = manifest("base")
        }

        do {
            _ = try pack(allFiles)
            Issue.record("Expected the pack to fail to load")
        } catch let ContentPackError.invalidFile(_, path, _) {
            #expect(path == expectedPath)
        }
    }

    @Test(arguments: ["/etc/passwd", "../outside.json", "scripts/../../x", "a//b", "./pack.json", #"scripts\eat.rob"#, ""])
    func directorySourcesRejectPathsOutsideThePack(path: String) {
        let source = DirectoryContentSource(directory: FileManager.default.temporaryDirectory)

        #expect(throws: ContentPackError.invalidPath(path)) {
            try source.data(atPath: path)
        }
    }

    @Test func unpackedFoldersLoadThroughTheDirectorySource() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("motive-engine-pack-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: folder.appendingPathComponent("scripts"),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(manifest("base").utf8).write(to: folder.appendingPathComponent("pack.json"))
        try Data(items([("fridge", "hunger")]).utf8).write(to: folder.appendingPathComponent("items.json"))

        let source = DirectoryContentSource(directory: folder)
        let loaded = try ContentPack(loadingFrom: source)

        #expect(loaded.definitions.map(\.id) == [try id("fridge")])
        #expect(try source.data(atPath: "swaf.json") == nil)
    }

    @Test func schemaExamplesLoadAndCompose() throws {
        let schemaFolder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../schema")
        func example(_ name: String) throws -> String {
            let schema = try JSONSerialization.jsonObject(
                with: Data(contentsOf: schemaFolder.appendingPathComponent(name))
            ) as? [String: Any]
            let first = try #require((schema?["examples"] as? [Any])?.first)
            return String(decoding: try JSONSerialization.data(withJSONObject: first), as: UTF8.self)
        }
        let base = try pack(["pack.json": manifest("base"), "items.json": items([("fridge", "hunger")])])
        let mod = try pack([
            "pack.json": try example("pack.json"),
            "items.json": try example("pack-items.json"),
            "scripts/feast.rob": """
            state default
                func stateEntry()
                    effect.fulfill("hunger", 3)
                end
            end
            """,
        ])

        let composition = try ContentComposer.compose([base, mod])

        #expect(composition.catalog.definitions.map(\.id.rawValue) == ["base:fridge", "kitchen-plus:radio"])
        #expect(composition.owner(of: try id("base:fridge")) == (try packID("kitchen-plus")))
    }

    @Test func directorySourcesRejectLinksThatLeaveThePack() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("motive-engine-link-\(UUID().uuidString)")
        let folder = root.appendingPathComponent("pack")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("secret".utf8).write(to: root.appendingPathComponent("secret.txt"))
        try Data("inside".utf8).write(to: folder.appendingPathComponent("real.txt"))
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("escape.txt"),
            withDestinationURL: root.appendingPathComponent("secret.txt")
        )
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("alias.txt"),
            withDestinationURL: folder.appendingPathComponent("real.txt")
        )
        let source = DirectoryContentSource(directory: folder)

        #expect(throws: ContentPackError.invalidPath("escape.txt")) {
            try source.data(atPath: "escape.txt")
        }
        #expect(try source.data(atPath: "alias.txt") == Data("inside".utf8))
    }

    @Test func newbieHouseExampleContentLoadsAndCoversItsLayout() throws {
        let example = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../Examples/NewbieHouse")
        let packs = try ["base", "newbie-extras", "broken-gadgets"].map { name in
            try ContentPack(loadingFrom: DirectoryContentSource(
                directory: example.appendingPathComponent("Content/\(name)")
            ))
        }

        let composition = try ContentComposer.compose(packs)
        let layout = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: example.appendingPathComponent("lot.json"))) as? [String: Any]
        )
        let placements = try #require(layout["items"] as? [[String: Any]])

        #expect(composition.owner(of: try id("base:television")) == (try packID("newbie-extras")))
        for placement in placements {
            let definition = try #require(placement["definition"] as? String)
            #expect(composition.catalog.definition(for: try id(definition)) != nil, "\(definition)")
        }
    }

    // MARK: Composition

    @Test func compositionQualifiesIDsAndOrdersDependenciesFirst() throws {
        let mod = try pack(["pack.json": manifest("mod", dependencies: ["base"]), "items.json": items([("lamp", "fun")])])
        let base = try pack(["pack.json": manifest("base"), "items.json": items([("fridge", "hunger")])])
        let extra = try pack(["pack.json": manifest("extra")])

        let composition = try ContentComposer.compose([mod, extra, base])

        #expect(composition.loadOrder == [try packID("extra"), try packID("base"), try packID("mod")])
        #expect(composition.catalog.definitions.map(\.id.rawValue) == ["base:fridge", "mod:lamp"])
        #expect(composition.owner(of: try id("base:fridge")) == (try packID("base")))
        #expect(composition.conflicts.isEmpty)
    }

    @Test func compositionRejectsBrokenPackSets() throws {
        let base = try pack(["pack.json": manifest("base")])
        let mod = try pack(["pack.json": manifest("mod", dependencies: ["base"])])
        let loopA = try pack(["pack.json": manifest("a", dependencies: ["b"])])
        let loopB = try pack(["pack.json": manifest("b", dependencies: ["a"])])

        #expect(throws: ContentPackError.duplicatePack(try packID("base"))) {
            try ContentComposer.compose([base, base])
        }
        #expect(throws: ContentPackError.missingDependency(try packID("mod"), dependency: try packID("base"))) {
            try ContentComposer.compose([mod])
        }
        #expect(throws: ContentPackError.dependencyCycle([try packID("a"), try packID("b")])) {
            try ContentComposer.compose([loopA, loopB])
        }
    }

    @Test func declaredOverridesReplaceDependencyContent() throws {
        let base = try pack(["pack.json": manifest("base"), "items.json": items([("fridge", "hunger")])])
        let mod = try pack([
            "pack.json": manifest("mod", dependencies: ["base"], overrides: ["base:fridge"]),
            "items.json": items([("base:fridge", "fun")]),
        ])

        let composition = try ContentComposer.compose([base, mod])

        let fridge = try #require(composition.catalog.definition(for: id("base:fridge")))
        #expect(fridge.interactions.first?.motiveEffects == [MotiveSignal(motiveType: .fun, strengthPerSecond: 2)])
        #expect(composition.owner(of: try id("base:fridge")) == (try packID("mod")))
    }

    @Test func invalidOverridesAreRejected() throws {
        let base = try pack(["pack.json": manifest("base"), "items.json": items([("fridge", "hunger")])])
        let other = try pack(["pack.json": manifest("other"), "items.json": items([("sofa", "energy")])])
        let undeclared = try pack([
            "pack.json": manifest("mod", dependencies: ["base"]),
            "items.json": items([("base:fridge", "fun")]),
        ])
        let notDependency = try pack([
            "pack.json": manifest("mod", dependencies: ["base"], overrides: ["other:sofa"]),
            "items.json": items([("other:sofa", "fun")]),
        ])
        let missingTarget = try pack([
            "pack.json": manifest("mod", dependencies: ["base"], overrides: ["base:oven"]),
            "items.json": items([("base:oven", "fun")]),
        ])
        let neverDefined = try pack(["pack.json": manifest("mod", dependencies: ["base"], overrides: ["base:fridge"])])
        let malformed = try pack(["pack.json": manifest("mod"), "items.json": items([(":lamp", "fun")])])
        let mod = try packID("mod")

        #expect(throws: ContentPackError.invalidOverride(mod, definitionID: try id("base:fridge"))) {
            try ContentComposer.compose([base, undeclared])
        }
        #expect(throws: ContentPackError.overrideTargetMissing(mod, definitionID: try id("other:sofa"))) {
            try ContentComposer.compose([other, base, notDependency])
        }
        #expect(throws: ContentPackError.overrideTargetMissing(mod, definitionID: try id("base:oven"))) {
            try ContentComposer.compose([base, missingTarget])
        }
        #expect(throws: ContentPackError.overrideNotDefined(mod, definitionID: try id("base:fridge"))) {
            try ContentComposer.compose([base, neverDefined])
        }
        #expect(throws: ContentPackError.invalidOverride(mod, definitionID: try id(":lamp"))) {
            try ContentComposer.compose([malformed])
        }
    }

    @Test func competingOverridesUseTheLatestPackAndReportTheConflict() throws {
        let base = try pack(["pack.json": manifest("base"), "items.json": items([("fridge", "hunger")])])
        let first = try pack([
            "pack.json": manifest("first", dependencies: ["base"], overrides: ["base:fridge"]),
            "items.json": items([("base:fridge", "fun")]),
        ])
        let second = try pack([
            "pack.json": manifest("second", dependencies: ["base"], overrides: ["base:fridge"]),
            "items.json": items([("base:fridge", "social")]),
        ])

        let composition = try ContentComposer.compose([base, first, second])

        #expect(composition.owner(of: try id("base:fridge")) == (try packID("second")))
        let conflict = try #require(composition.conflicts.first)
        #expect(composition.conflicts.count == 1)
        #expect(conflict.definitionID == (try id("base:fridge")))
        #expect(conflict.packIDs == [try packID("first"), try packID("second")])
    }

    @Test func composedContentRunsInASession() throws {
        let base = try pack([
            "pack.json": manifest("base"),
            "items.json": #"""
            {"items": [{"id": "fridge", "name": "Fridge", "modifiers": ["appliance"],
              "interactions": [{"id": "eat", "name": "Eat", "duration": 10,
                                "advertises": {"hunger": 2}, "script": "eat"}]}]}
            """#,
            "scripts/eat.rob": """
            state default
                func stateEntry()
                    effect.fulfill("hunger", 3)
                end
            end
            """,
        ])
        let composition = try ContentComposer.compose([base])
        let simID = try #require(SimID("bob"))
        let lot = try LotState(
            id: #require(LotID("home")),
            bounds: GridSize(width: 3, height: 1),
            placedItems: [PlacedItem(id: #require(ItemInstanceID("fridge-1")), definitionID: id("base:fridge"), position: GridPosition(x: 2, y: 0))]
        )
        var levels = Dictionary(uniqueKeysWithValues: MotiveType.allCases.map { ($0, 80.0) })
        levels[.hunger] = 20
        var session = try SimulationSession(
            state: SimulationState(
                sims: [SimStateData(id: simID, motives: MotiveLevels(levels: levels), posture: .standing, currentLotID: lot.id, position: GridPosition(x: 0, y: 0))],
                households: [],
                lots: [lot]
            ),
            itemCatalog: composition.catalog,
            motiveDecayRates: MotiveDecayRates(ratesPerSecond: Dictionary(uniqueKeysWithValues: MotiveType.allCases.map { ($0, 0.0) }))
        )

        try session.step(bySeconds: 0)

        #expect(session.state.sim(for: simID)?.activeAction?.motiveEffects == [
            MotiveSignal(motiveType: .hunger, strengthPerSecond: 3),
        ])
    }
}
