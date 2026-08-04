import Foundation

let unterminatedStringMessage = "unterminated string"

enum LexingError: Error, CustomStringConvertible {
    case unexpectedCharacter(Character, at: Int)
    case malformedNumber(String)

    var description: String {
        switch self {
        case let .unexpectedCharacter(character, index):
            "Unexpected character \(character) at position \(index)"
        case let .malformedNumber(text):
            "Malformed number literal \(text)"
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

    mutating func tokenize(from _: String) throws -> [Token] {
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

        return try lexSymbol()
    }

    mutating func skipSpacesAndComments() {
        while let character = peek() {
            if character == " " || character == "\t" || character == "\r" {
                advance()
            } else if character == "#" {
                while let inner = peek(), inner != "\n" {
                    advance()
                }
            } else if character == "/", peek(next: true) == "/" {
                while let inner = peek(), inner != "\n" {
                    advance()
                }
            } else {
                break
            }
        }
    }

    func endOfLine(_ characters: [Character],
                   from start: Int) -> Int
    {
        var index = start
        while index < characters.count, characters[index] != "\n" {
            index += 1
        }
        return index
    }

    mutating func lexSymbol() throws -> Token {
        let startLine = line
        let twoCharacter = String([peek() ?? " ", peek(next: true) ?? " "])
        for symbol in ["<=", ">=", "<>", "=>"] where twoCharacter == symbol {
            advance()
            advance()
            return Token(kind: .symbol(symbol), line: startLine)
        }

        guard let character = peek(), "+-*/=<>(),".contains(character) else {
            throw ItemScriptError(message: "unexpected character \(peek().map(String.init) ?? "")", line: startLine)
        }
        advance()
        return Token(kind: .symbol(String(character)), line: startLine)
    }
}
