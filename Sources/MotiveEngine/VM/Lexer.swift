import Foundation


let unterminatedStringMessage = "unterminated string"

enum LexingError: Error, CustomStringConvertible {
    case unexpectedCharacter(Character, at: Int)
    case malformedNumber(String)
    
    var description: String {
        switch self {
        case .unexpectedCharacter(let character, let index):
            return "Unexpected character \(character) at position \(index)"
        case .malformedNumber(let text):
            return "Malformed number literal \(text)"
        }
    }
}

struct Lexer {
    private static let remarkKeyword = "rimarko"
    
    mutating func tokens(from source: String) throws -> [Token] {
        var tokens: [Token] = []
        while true {
         
        }
        return tokens
    }
    
    func startLineComment(_ characters: [Character], at index: Int) -> Bool {
        if characters[index] == "#" { return true }
        return matchesStandaloneWord(
            Self.remarkKeyword,
            in: characters,
            at: index
        )
    }
    
    func matchesStandaloneWord(_ word: String, in characters: [Character], at index: Int) -> Bool {
        
        return true
    }
    
    func normalizedLineEndings(in source: String) -> String {
        source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
    
    func sanitized(_ source: String) -> String {
        let normalized = normalizedLineEndings(in: source)
        let characters = Array(normalized)
        var result = ""
        result.reserveCapacity(characters.count)
        var index = 0
        
        while index < characters.count {
            if startLineComment(characters, at: index) {
                index = endOfLine(characters, from: index)
                continue
            }
            result.append(characters[index])
            index += 1
        }
        
        return ""
    }
    
    func endOfLine(_ characters: [Character],
                       from start: Int)  -> Int {
        var index = start
        while index < characters.count, characters[index] != "\n" {
            index += 1
        }
        return index
    }
}

