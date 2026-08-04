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
    let characters: [Character]
    var position = 0
    var line = 1
    
    init(_ source: String) {
        characters = Array(source)
    }
    
    mutating func tokenize(from source: String) throws -> [Token] {
        var tokens: [Token] = []
        while true {
            let token = try nextToken()
            tokens.append(token)
            if token.kind == .endOfInput { break }
        }
        return tokens
    }
    
    func peek(next: Bool = false) -> Character? {
        
        if next {
            return position < characters.count ? characters[position + 1] : nil
        }
        
        return position < characters.count ? characters[position] : nil
    }
    
    mutating func advance() {
        position += 1
    }
    
    mutating func nextToken() throws -> Token {
        guard let character = peek() else {
            return Token(kind: .endOfInput, line: line)
        }
        if character == "\n" {
            advance()
            let token = Token(kind: .newline, line: line)
            line += 1
            return token
        }
        
        // TODO: replace filler with lexSymbol()
        return (Token(kind: .endOfInput, line: line))
    }
    
    mutating func skipSpacesAndComments() {
        let nextChar = peek(next: true)
            while let character = peek() {
                switch character {
                case " ", "\t", "\r":
                    advance()
                case "#":
                    while let inner = peek(), inner != "\n" {
                        advance()
                    }
                case "/" where nextChar == "/":
                    while let inner = peek(), inner != "\n" {
                        advance()
                    }
                default:
                    break
                }
            }
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

