import Foundation

/// A loaded content pack: its manifest, item definitions, and files.
///
/// Definitions keep the IDs written in the pack. `ContentComposer` qualifies
/// them with the pack ID when packs are combined.
public struct ContentPack: Sendable {
    /// The manifest file name at the root of every pack.
    public static let manifestPath = "pack.json"

    /// The optional item definitions file.
    public static let itemsPath = "items.json"

    /// The folder that holds Robusta scripts named by interactions.
    public static let scriptsFolder = "scripts"

    /// The pack's metadata.
    public let manifest: ContentPackManifest

    /// Item definitions with the IDs written in the pack.
    public let definitions: [ItemDefinition]

    /// Where the pack's files come from, for extensions that read their own
    /// files, such as wants and fears.
    public let source: any ContentSource

    /// Creates a pack from already-built values.
    public init(manifest: ContentPackManifest, definitions: [ItemDefinition], source: any ContentSource) {
        self.manifest = manifest
        self.definitions = definitions
        self.source = source
    }

    /// Loads a pack: its manifest, its item definitions if present, and every
    /// script those definitions name.
    ///
    /// Scripts are compiled now, so script errors are reported when the pack
    /// loads rather than when a Sim first uses an item.
    ///
    /// - Throws: `ContentPackError.invalidFile` for a missing manifest, a
    ///   malformed or invalid file, a missing script, or a script that fails
    ///   to compile; other `ContentPackError` values for an invalid manifest.
    public init(loadingFrom source: any ContentSource) throws {
        guard let manifestData = try source.data(atPath: Self.manifestPath) else {
            throw ContentPackError.invalidFile(nil, path: Self.manifestPath, reason: "The pack has no manifest.")
        }
        let manifest: ContentPackManifest
        do {
            manifest = try ContentPackManifest(jsonData: manifestData)
        } catch let error as ContentPackError {
            throw error
        } catch {
            throw ContentPackError.invalidFile(nil, path: Self.manifestPath, reason: String(describing: error))
        }

        self.manifest = manifest
        self.source = source
        definitions = try Self.loadDefinitions(of: manifest.id, from: source)
    }

    private static func loadDefinitions(
        of packID: ContentPackID,
        from source: any ContentSource
    ) throws -> [ItemDefinition] {
        guard let itemsData = try source.data(atPath: itemsPath) else {
            return []
        }
        let file: ItemContentFile
        do {
            file = try JSONDecoder().decode(ItemContentFile.self, from: itemsData)
        } catch {
            throw ContentPackError.invalidFile(packID, path: itemsPath, reason: String(describing: error))
        }

        var scripts: [String: InteractionScript] = [:]
        let loadScript = { (name: String) throws -> InteractionScript in
            if let script = scripts[name] {
                return script
            }
            let script = try Self.loadScript(named: name, of: packID, from: source)
            scripts[name] = script
            return script
        }
        do {
            return try file.definitions(script: loadScript)
        } catch let error as ContentPackError {
            throw error
        } catch {
            throw ContentPackError.invalidFile(packID, path: itemsPath, reason: String(describing: error))
        }
    }

    private static func loadScript(
        named name: String,
        of packID: ContentPackID,
        from source: any ContentSource
    ) throws -> InteractionScript {
        let path = "\(scriptsFolder)/\(name).rob"
        guard !name.isEmpty, !name.contains("/"), !name.contains("\\") else {
            throw ContentPackError.invalidPath(path)
        }
        guard let data = try source.data(atPath: path) else {
            throw ContentPackError.invalidFile(packID, path: path, reason: "The script does not exist.")
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ContentPackError.invalidFile(packID, path: path, reason: "The script is not UTF-8 text.")
        }
        do {
            return try InteractionScript(source: text)
        } catch {
            throw ContentPackError.invalidFile(packID, path: path, reason: String(describing: error))
        }
    }
}
