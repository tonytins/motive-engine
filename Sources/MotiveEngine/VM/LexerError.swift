import Foundation

/// An error produced while tokenizing Robusta source.
public struct LexError: Error, Equatable, Sendable {
    public let message: String
    public let line: Int

    public init(message: String, line: Int) {
        self.message = message
        self.line = line
    }
}