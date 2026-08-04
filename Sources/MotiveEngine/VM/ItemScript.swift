// Basil
import Foundation

let scriptKeywords: Set<String> = [
    "let", "emit", "if", "then", "else", "end", "and", "or", "not",
    "true", "false", "hasmodifier"
]

struct ItemScriptError: Error, CustomStringConvertible, Equatable {
    let message: String
    let line: Int
    
    var description: String {
        "line \(line): \(message)"
    }
}


struct ItemScript: Sendable {
    private let states: String
    
    init(sources: String) throws {
        var lexer = Lexer(source)
        // let tokens = try lexer.
    }
}
