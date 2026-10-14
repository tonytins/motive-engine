import Foundation

/// Turns Robusta source text into a flat stream of tokens.
public enum Lexer {
    public static func tokenize(_ source: String) throws -> [Token] {
        var scanner = Scanner(source: source)
        return try scanner.tokenize()
    }
}

/// The stateful cursor that walks source text one character at a time.
///
/// Comments are stripped here rather than surfaced as tokens. `//` and `#`
/// both start a line comment, and `REM` does too, case-insensitively, as a
/// nod back to BASIC.
private struct Scanner {
    private let characters: [Character]
    private var index = 0
    private var line = 1

    init(source: String) {
        characters = Array(source)
    }

    mutating func tokenize() throws -> [Token] {
        var tokens: [Token] = []

        while true {
            skipWhitespaceAndComments()
            guard !isAtEnd else { break }

            if current == "\"" {
                tokens.append(try scanString())
                continue
            }

            if current.isNumber {
                tokens.append(try scanNumber())
                continue
            }

            if current.isLetter || current == "_" {
                let word = scanWord()
                guard word.uppercased() != "REM" else {
                    skipToEndOfLine()
                    continue
                }
                tokens.append(Token(kind: classify(word), line: line))
                continue
            }

            tokens.append(try scanSymbol())
        }

        tokens.append(Token(kind: .endOfInput, line: line))
        return tokens
    }

    private var isAtEnd: Bool { index >= characters.count }
    private var current: Character { characters[index] }

    private func peek(offset: Int = 1) -> Character? {
        let peekIndex = index + offset
        guard peekIndex < characters.count else { return nil }
        return characters[peekIndex]
    }

    private mutating func advance() {
        index += 1
    }

    private mutating func skipWhitespaceAndComments() {
        while !isAtEnd {
            if current == "\n" {
                line += 1
                advance()
                continue
            }
            if current.isWhitespace {
                advance()
                continue
            }
            if current == "#" {
                skipToEndOfLine()
                continue
            }
            if current == "/" && peek() == "/" {
                skipToEndOfLine()
                continue
            }
            break
        }
    }

    private mutating func skipToEndOfLine() {
        while !isAtEnd, current != "\n" {
            advance()
        }
    }

    private mutating func scanWord() -> String {
        var word = ""
        while !isAtEnd, current.isLetter || current.isNumber || current == "_" {
            word.append(current)
            advance()
        }
        return word
    }

    private func classify(_ word: String) -> TokenKind {
        guard word != "_" else { return .symbol(.underscore) }
        guard let keyword = Keyword(rawValue: word) else { return .identifier(word) }
        return .keyword(keyword)
    }

    private mutating func scanNumber() throws -> Token {
        let startLine = line
        var text = ""

        while !isAtEnd, current.isNumber {
            text.append(current)
            advance()
        }

        if !isAtEnd, current == ".", let next = peek(), next.isNumber {
            text.append(current)
            advance()
            while !isAtEnd, current.isNumber {
                text.append(current)
                advance()
            }
        }

        guard let value = Double(text) else {
            throw LexError(message: "Invalid number literal '\(text)'.", line: startLine)
        }
        return Token(kind: .numberLiteral(value), line: startLine)
    }

    private mutating func scanString() throws -> Token {
        let startLine = line
        advance() // consume the opening quote
        var text = ""

        while !isAtEnd, current != "\"" {
            if current == "\\", let escaped = peek() {
                text.append(unescape(escaped))
                advance()
                advance()
                continue
            }
            if current == "\n" {
                line += 1
            }
            text.append(current)
            advance()
        }

        guard !isAtEnd else {
            throw LexError(message: "Unterminated string literal.", line: startLine)
        }
        advance() // consume the closing quote
        return Token(kind: .stringLiteral(text), line: startLine)
    }

    private func unescape(_ character: Character) -> Character {
        switch character {
        case "n": "\n"
        case "t": "\t"
        case "\"": "\""
        case "\\": "\\"
        default: character
        }
    }

    private mutating func scanSymbol() throws -> Token {
        let startLine = line
        let first = current

        if let next = peek() {
            let pair = String([first, next])
            if let symbol = Symbol(rawValue: pair) {
                advance()
                advance()
                return Token(kind: .symbol(symbol), line: startLine)
            }
        }

        guard let symbol = Symbol(rawValue: String(first)) else {
            throw LexError(message: "Unexpected character '\(first)'.", line: startLine)
        }
        advance()
        return Token(kind: .symbol(symbol), line: startLine)
    }
}