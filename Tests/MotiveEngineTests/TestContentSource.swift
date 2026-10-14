import Foundation
import MotiveEngine

/// An in-memory content pack, keyed by relative path.
struct MemorySource: ContentSource {
    let files: [String: String]

    func data(atPath path: String) throws -> Data? {
        files[path].map { Data($0.utf8) }
    }
}
