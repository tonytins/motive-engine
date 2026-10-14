import Foundation

/// A single lexical token, one unit of Robusta source text.
public struct Token: Sendable, Equatable {
    public let kind: TokenKind
    public let line: Int

    public init(kind: TokenKind, line: Int) {
        self.kind = kind
        self.line = line
    }
}

/// The kind of value a single token carries.
public enum TokenKind: Sendable, Equatable {
    case keyword(Keyword)
    case identifier(String)
    case numberLiteral(Double)
    case stringLiteral(String)
    case symbol(Symbol)
    case endOfInput
}

/// A reserved word in Robusta's frontend syntax.
///
/// Cases whose Swift name would collide with a Swift keyword carry an
/// explicit raw value instead of a backtick-escaped case name, matching how
/// `Trilean` avoided the same collision.
public enum Keyword: String, Sendable, Equatable, CaseIterable {
    case mod
    case state
    case end
    case funcKeyword = "func"
    case val
    case mut
    case ifKeyword = "if"
    case elseKeyword = "else"
    case match
    case caseKeyword = "case"
    case tryKeyword = "try"
    case catchKeyword = "catch"
    case print
    case returnKeyword = "return"
    case trueKeyword = "true"
    case falseKeyword = "false"
    case unknownKeyword = "Unknown"
    case noneKeyword = "None"
}

/// A punctuation or operator symbol.
public enum Symbol: String, Sendable, Equatable, CaseIterable {
    case leftParenthesis = "("
    case rightParenthesis = ")"
    case comma = ","
    case dot = "."
    case plus = "+"
    case minus = "-"
    case asterisk = "*"
    case slash = "/"
    case equalEqual = "=="
    case notEqual = "!="
    case andAnd = "&&"
    case orOr = "||"
    case not = "!"
    case equal = "="
    case underscore = "_"
}