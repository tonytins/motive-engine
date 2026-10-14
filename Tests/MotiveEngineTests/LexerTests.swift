import Testing
@testable import MotiveEngine

@Suite("Lexer")
struct LexerTests {
    @Test("val x = 2 + 3 tokenizes to the expected stream")
    func tokenizesValueDeclaration() throws {
        let tokens = try Lexer.tokenize("val x = 2 + 3")
        #expect(tokens.map(\.kind) == [
            .keyword(.val),
            .identifier("x"),
            .symbol(.equal),
            .numberLiteral(2),
            .symbol(.plus),
            .numberLiteral(3),
            .endOfInput
        ])
    }

    @Test("mut val counter = 0 tokenizes both keywords")
    func tokenizesMutableValueDeclaration() throws {
        let tokens = try Lexer.tokenize("mut val counter = 0")
        #expect(tokens.map(\.kind) == [
            .keyword(.mut),
            .keyword(.val),
            .identifier("counter"),
            .symbol(.equal),
            .numberLiteral(0),
            .endOfInput
        ])
    }

    @Test("a bare state transition tokenizes as keyword plus identifier, no block")
    func tokenizesStateTransition() throws {
        let tokens = try Lexer.tokenize("state active")
        #expect(tokens.map(\.kind) == [
            .keyword(.state),
            .identifier("active"),
            .endOfInput
        ])
    }

    @Test("a lone underscore tokenizes as the wildcard symbol, not an identifier")
    func tokenizesUnderscoreAsWildcard() throws {
        let tokens = try Lexer.tokenize("_")
        #expect(tokens.map(\.kind) == [.symbol(.underscore), .endOfInput])
    }

    @Test("an identifier starting with underscore stays an identifier")
    func tokenizesUnderscorePrefixedIdentifier() throws {
        let tokens = try Lexer.tokenize("_foo")
        #expect(tokens.map(\.kind) == [.identifier("_foo"), .endOfInput])
    }

    @Test("mathUtils.add(2, 3) tokenizes member access and call syntax")
    func tokenizesMemberAccessAndCall() throws {
        let tokens = try Lexer.tokenize("mathUtils.add(2, 3)")
        #expect(tokens.map(\.kind) == [
            .identifier("mathUtils"),
            .symbol(.dot),
            .identifier("add"),
            .symbol(.leftParenthesis),
            .numberLiteral(2),
            .symbol(.comma),
            .numberLiteral(3),
            .symbol(.rightParenthesis),
            .endOfInput
        ])
    }

    @Test("two-character operators tokenize as one symbol, not two", arguments: [
        ("a == b", Symbol.equalEqual),
        ("a != b", Symbol.notEqual),
        ("a && b", Symbol.andAnd),
        ("a || b", Symbol.orOr)
    ])
    func tokenizesTwoCharacterOperators(source: String, expected: Symbol) throws {
        let tokens = try Lexer.tokenize(source)
        #expect(tokens.map(\.kind) == [
            .identifier("a"),
            .symbol(expected),
            .identifier("b"),
            .endOfInput
        ])
    }

    @Test("string literals support basic escapes")
    func tokenizesStringWithEscapes() throws {
        let tokens = try Lexer.tokenize(#""hello \"world\"\n""#)
        #expect(tokens.map(\.kind) == [
            .stringLiteral("hello \"world\"\n"),
            .endOfInput
        ])
    }

    @Test("Both Trilean spellings and None tokenize as keywords")
    func caseSensitivityDistinguishesKeywordsFromIdentifiers() throws {
        let keywordTokens = try Lexer.tokenize("None true True false False Unknown unknown")
        #expect(keywordTokens.map(\.kind) == [
            .keyword(.noneKeyword),
            .keyword(.trueKeyword),
            .keyword(.trueTrileanKeyword),
            .keyword(.falseKeyword),
            .keyword(.falseTrileanKeyword),
            .keyword(.unknownKeyword),
            .keyword(.lowercaseUnknownKeyword),
            .endOfInput
        ])

        let identifierTokens = try Lexer.tokenize("none")
        #expect(identifierTokens.map(\.kind) == [
            .identifier("none"),
            .endOfInput
        ])
    }

    @Test("// # and REM all start a line comment", arguments: [
        "val x = 1 // trailing comment",
        "val x = 1 # trailing comment",
        "val x = 1 REM trailing comment",
        "val x = 1 rem trailing comment"
    ])
    func stripsCommentsRegardlessOfStyle(source: String) throws {
        let tokens = try Lexer.tokenize(source)
        #expect(tokens.map(\.kind) == [
            .keyword(.val),
            .identifier("x"),
            .symbol(.equal),
            .numberLiteral(1),
            .endOfInput
        ])
    }

    @Test("a REM comment on its own line consumes only that line")
    func remCommentDoesNotConsumeFollowingLine() throws {
        let tokens = try Lexer.tokenize("REM a note\nval x = 1")
        #expect(tokens.map(\.kind) == [
            .keyword(.val),
            .identifier("x"),
            .symbol(.equal),
            .numberLiteral(1),
            .endOfInput
        ])
    }

    @Test("an unterminated string throws a LexError")
    func unterminatedStringThrows() {
        #expect(throws: LexError.self) {
            try Lexer.tokenize("\"never closed")
        }
    }

    @Test("an unrecognized character throws a LexError")
    func unrecognizedCharacterThrows() {
        #expect(throws: LexError.self) {
            try Lexer.tokenize("val x = 1 @ 2")
        }
    }
}