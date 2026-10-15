import Foundation
import MotiveEngine

/// Finds, loads, and composes the example's content packs.
enum ContentLoading {
    /// Loads the bundled packs and any extra pack folders, composes them, and
    /// prints the load order and any override conflicts.
    static func load(includingBrokenMod: Bool, extraPacks: [URL]) throws -> ContentComposition {
        let contentFolder = try bundledURL("Content", extension: nil)
        var folders = ["base", "newbie-extras"].map { contentFolder.appendingPathComponent($0) }
        if includingBrokenMod {
            folders.append(contentFolder.appendingPathComponent("broken-gadgets"))
        }
        folders += extraPacks

        let packs = try folders.map(loadPack)
        let composition = try ContentComposer.compose(packs)
        printSummary(of: packs, composition: composition)
        return composition
    }

    /// The URL of a file or folder bundled with the example.
    static func bundledURL(_ name: String, extension fileExtension: String?) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension) else {
            throw NewbieHouseError.missingResource(name)
        }
        return url
    }

    /// Loads one pack, naming its folder if it fails.
    private static func loadPack(at folder: URL) throws -> ContentPack {
        do {
            return try ContentPack(loadingFrom: DirectoryContentSource(directory: folder))
        } catch {
            throw NewbieHouseError.packFailedToLoad(folder: folder.path, reason: String(describing: error))
        }
    }

    private static func printSummary(of packs: [ContentPack], composition: ContentComposition) {
        let packsByID = Dictionary(uniqueKeysWithValues: packs.map { ($0.manifest.id, $0.manifest) })
        print("Content packs, in load order:")
        for manifest in composition.loadOrder.compactMap({ packsByID[$0] }) {
            var line = "  \(manifest.id.rawValue): \(manifest.name)"
            if !manifest.dependencies.isEmpty {
                line += ", needs \(manifest.dependencies.map(\.rawValue).joined(separator: ", "))"
            }
            if !manifest.overrides.isEmpty {
                line += ", replaces \(manifest.overrides.map(\.rawValue).joined(separator: ", "))"
            }
            print(line)
        }
        for conflict in composition.conflicts {
            let packs = conflict.packIDs.map(\.rawValue).joined(separator: ", ")
            print("  Conflict: \(packs) all replace \(conflict.definitionID.rawValue); the last one wins")
        }
        print("")
    }
}
