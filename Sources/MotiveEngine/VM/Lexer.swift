import Foundation


let unterminatedStringMessage = "unterminated string"

struct Lexer {
    private let characters: [Character]
    private var position = 0
    private var line = 1
    
    init(_ source: String) {
        characters = Array(source)
    }
    
    
    func peek() -> Character? {
        position < characters.count ? characters[position] : nil
    }
    
    func peekNext() -> Character? {
        position < characters.count ? characters[position + 1] : nil
    }
    
    mutating func advance() {
        position += 1
    }
    
    
    mutating func tokenize() -> [Token] {
        var tokens: [Token] = []
        while true {
            // let token = try nextToken()
            // tokens.append(tokens)
        
        }
        return tokens
    }
    
    mutating func nextToken() throws -> Token {
        skipSpacesAndComments()
        guard let character = peek() else {
            return Token(kind: .endOfInput, line: line)
        }
        
        if character == "\n" {
                    advance()
                    let token = Token(kind: .newline, line: line)
                    line += 1
                    return token
                }
                if character.isNumber {
                    return lexNumber()
                }
                if character == "\"" {
                    return try lexString()
                }
                if character.isLetter || character == "_" {
                    return lexWord()
                }
        
        return try lexSymbol()
    }
    
    func lexNumber() -> Token {
        var startLine = line
        var text = ""
        
        return Token(kind: .number(Double(text) ?? 0), line: startLine)
    }
    
    mutating func lexString() throws -> Token {
        var startLine = line
        advance()
        var text = ""
        
        while let character = peek(), character != "\"" {
            if character == "\n" {
                throw ItemScriptError(message:unterminatedStringMessage, line: startLine)
                text.append(character)
                advance()
            }
            guard peek() == "\"" else {
                throw ItemScriptError(message:unterminatedStringMessage, line: startLine)
            }
            advance()
            return Token(kind: .string(text), line: startLine)
        }
        
        return Token(kind: .number(Double(text) ?? 0), line: startLine)
    }
    
    func lexWord() -> Token {
        var startLine = line
        var text = ""
        
        return Token(kind: .number(Double(text) ?? 0), line: startLine)
    }
    
    mutating func skipSpacesAndComments() {
        while let character = peek() {
            switch character {
            case " ", "\t", "\r":
                advance()
            case "#":
                while let inner = peek(), inner != "\n" {
                    advance()
                }
            default:
                break
            }
        }
    }

    func lexSymbol() throws -> Token {
        let character = characters[position]
        throw ItemScriptError(
            message: "unexpected character \(character)",
            line: line
        )
    }
}

