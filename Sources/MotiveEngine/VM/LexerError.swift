import Foundation

/// An error produced while tokenizing Robusta source.
public struct LexError: Error, Equatable, Sendable, CustomStringConvertible {
    /// A description of the problem.
    public let message: String

    /// The 1-based source line where the problem was found.
    public let line: Int

    /// Creates an error for a source line.
    public init(message: String, line: Int) {
        self.message = message
        self.line = line
    }

    /// The message prefixed with its line number.
    public var description: String {
        "line \(line): \(message)"
    }
}