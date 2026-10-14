import Foundation

/// A stable identifier for one content pack, such as the base game or a mod.
///
/// Pack IDs prefix the item definitions they provide, as in `base:fridge`,
/// so they cannot contain `:` or whitespace.
public struct ContentPackID: StringIdentifier {
    /// The pack's identifier.
    public let rawValue: String

    /// Creates an identifier, or returns `nil` when `rawValue` is empty or
    /// contains `:` or whitespace.
    public init?(_ rawValue: String) {
        guard !rawValue.isEmpty,
              !rawValue.contains(":"),
              !rawValue.contains(where: \.isWhitespace)
        else {
            return nil
        }
        self.rawValue = rawValue
    }
}

/// The metadata that describes a content pack.
///
/// A manifest is the `pack.json` file at the root of a pack.
public struct ContentPackManifest: Equatable, Sendable {
    /// The pack content formats this engine can read.
    public static let supportedFormats: ClosedRange<Int> = 1 ... 1

    /// The pack's stable identity.
    public let id: ContentPackID

    /// The player-facing name.
    public let name: String

    /// The pack's own version, for display. The engine does not compare it.
    public let version: String

    /// The content format the pack is written in.
    public let format: Int

    /// Packs that must load before this one.
    public let dependencies: [ContentPackID]

    /// Definitions from other packs that this pack deliberately replaces.
    ///
    /// Each ID is fully qualified, such as `base:fridge`, and must belong to
    /// one of the pack's dependencies.
    public let overrides: [ItemDefinitionID]

    /// Creates a validated manifest.
    ///
    /// - Throws: `ContentPackError` for an empty name or version, an
    ///   unsupported format, a dependency on itself, duplicate dependencies or
    ///   overrides, or an override that is not qualified with another pack's ID.
    public init(
        id: ContentPackID,
        name: String,
        version: String,
        format: Int,
        dependencies: [ContentPackID] = [],
        overrides: [ItemDefinitionID] = []
    ) throws {
        guard !name.isEmpty, !version.isEmpty else {
            throw ContentPackError.invalidManifest(id, reason: "The name and version must not be empty.")
        }
        guard Self.supportedFormats.contains(format) else {
            throw ContentPackError.unsupportedFormat(id, format: format)
        }
        guard !dependencies.contains(id) else {
            throw ContentPackError.invalidManifest(id, reason: "A pack cannot depend on itself.")
        }
        guard Set(dependencies).count == dependencies.count else {
            throw ContentPackError.invalidManifest(id, reason: "Dependencies must be unique.")
        }
        guard Set(overrides).count == overrides.count else {
            throw ContentPackError.invalidManifest(id, reason: "Overrides must be unique.")
        }
        for definitionID in overrides {
            guard let owner = definitionID.packID, owner != id else {
                throw ContentPackError.invalidOverride(id, definitionID: definitionID)
            }
        }

        self.id = id
        self.name = name
        self.version = version
        self.format = format
        self.dependencies = dependencies
        self.overrides = overrides
    }

    /// Decodes and validates a `pack.json` manifest.
    ///
    /// - Throws: `DecodingError` for malformed JSON or `ContentPackError` for
    ///   invalid values.
    public init(jsonData: Data) throws {
        let payload = try JSONDecoder().decode(ManifestPayload.self, from: jsonData)
        try self.init(
            id: payload.id,
            name: payload.name,
            version: payload.version,
            format: payload.format,
            dependencies: payload.dependencies ?? [],
            overrides: payload.overrides ?? []
        )
    }
}

private struct ManifestPayload: Decodable {
    let id: ContentPackID
    let name: String
    let version: String
    let format: Int
    let dependencies: [ContentPackID]?
    let overrides: [ItemDefinitionID]?
}

extension ItemDefinitionID {
    /// The pack named before `:` in a qualified ID, such as `base` in `base:fridge`.
    var packID: ContentPackID? {
        guard let separator = rawValue.firstIndex(of: ":") else {
            return nil
        }
        return ContentPackID(String(rawValue[..<separator]))
    }
}

/// An invalid content pack, or packs that cannot be loaded together.
public enum ContentPackError: Error, Equatable, Sendable {
    /// The manifest has an invalid value.
    case invalidManifest(ContentPackID, reason: String)

    /// The pack uses a content format this engine cannot read.
    case unsupportedFormat(ContentPackID, format: Int)

    /// An override is unqualified, names the pack itself, or is not declared
    /// in the manifest.
    case invalidOverride(ContentPackID, definitionID: ItemDefinitionID)

    /// A declared override targets a pack that is not a dependency, or a
    /// definition that the target pack does not provide.
    case overrideTargetMissing(ContentPackID, definitionID: ItemDefinitionID)

    /// A declared override is never defined by the pack.
    case overrideNotDefined(ContentPackID, definitionID: ItemDefinitionID)

    /// Two packs use the same ID.
    case duplicatePack(ContentPackID)

    /// A pack depends on a pack that was not supplied.
    case missingDependency(ContentPackID, dependency: ContentPackID)

    /// Packs depend on each other in a cycle.
    case dependencyCycle([ContentPackID])

    /// A pack file is missing, malformed, or fails to compile.
    case invalidFile(ContentPackID?, path: String, reason: String)

    /// A file path is absolute or leaves the pack's folder.
    case invalidPath(String)
}
