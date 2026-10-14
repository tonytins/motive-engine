import Foundation

/// A place that provides a content pack's files by relative path.
///
/// Paths use `/` separators, such as `scripts/eat.rob`. Games can provide
/// their own source, for example one that reads from an archive.
public protocol ContentSource: Sendable {
    /// Returns a file's contents, or `nil` when the file does not exist.
    ///
    /// - Throws: An error when the file exists but cannot be read.
    func data(atPath path: String) throws -> Data?
}

/// Reads an unpacked content pack from a folder.
public struct DirectoryContentSource: ContentSource {
    /// The pack's root folder.
    public let directory: URL

    /// Creates a source for the pack in `directory`.
    public init(directory: URL) {
        self.directory = directory
    }

    /// Returns a file inside the folder, or `nil` when it does not exist.
    ///
    /// Symbolic links are followed only when they resolve to a file inside
    /// the folder, so a pack cannot read files elsewhere on disk.
    ///
    /// - Throws: `ContentPackError.invalidPath` for an absolute path, one that
    ///   leaves the folder, or a link that resolves outside it, or a file
    ///   system error when reading fails.
    public func data(atPath path: String) throws -> Data? {
        let components = try ContentPath.components(of: path)
        let url = components.reduce(directory) { $0.appendingPathComponent($1) }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let root = directory.resolvingSymlinksInPath().standardizedFileURL.path
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard resolved.hasPrefix(root.hasSuffix("/") ? root : root + "/") else {
            throw ContentPackError.invalidPath(path)
        }
        return try Data(contentsOf: url)
    }
}

/// Validation for relative paths inside a content pack.
enum ContentPath {
    /// Splits a relative path into components, rejecting anything that could
    /// reach outside the pack.
    static func components(of path: String) throws -> [String] {
        let components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.contains("\\"),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else {
            throw ContentPackError.invalidPath(path)
        }
        return components
    }
}
