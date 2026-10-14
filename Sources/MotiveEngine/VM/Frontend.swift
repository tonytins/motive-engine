/// Converts Robusta source text into its abstract syntax tree.
public protocol Frontend {
    func parse(_ source: String) throws -> [Statement]
}

/// The production parser for the Robusta language.
public struct RobustaFrontend: Frontend {
    public init() {}

    public func parse(_ source: String) throws -> [Statement] {
        var parser = try Parser(tokens: Lexer.tokenize(source))
        return try parser.parseProgram()
    }
}

/// A syntax error produced by the Robusta frontend.
public struct ParseError: Error, Equatable, Sendable, CustomStringConvertible {
    public let message: String
    public let line: Int

    public init(message: String, line: Int) {
        self.message = message
        self.line = line
    }

    public var description: String {
        "line \(line): \(message)"
    }
}

private struct Parser {
    private let tokens: [Token]
    private var position = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    mutating func parseProgram() throws -> [Statement] {
        let statements = try parseStatements(stoppingAt: [], context: .topLevel)
        guard isAtEnd else {
            throw error("Unexpected token after program.")
        }
        return statements
    }

    private var current: Token { tokens[position] }
    private var isAtEnd: Bool { current.kind == .endOfInput }

    private func peek(_ offset: Int = 1) -> Token {
        let index = position + offset
        return tokens[min(index, tokens.count - 1)]
    }

    private mutating func advance() -> Token {
        let token = current
        if !isAtEnd { position += 1 }
        return token
    }

    private mutating func match(_ keyword: Keyword) -> Bool {
        guard current.kind == .keyword(keyword) else { return false }
        _ = advance()
        return true
    }

    private mutating func match(_ symbol: Symbol) -> Bool {
        guard current.kind == .symbol(symbol) else { return false }
        _ = advance()
        return true
    }

    private mutating func expect(_ keyword: Keyword) throws {
        guard match(keyword) else {
            throw error("Expected '\(keyword.rawValue)'.")
        }
    }

    private mutating func expect(_ symbol: Symbol) throws {
        guard match(symbol) else {
            throw error("Expected '\(symbol.rawValue)'.")
        }
    }

    private mutating func expectIdentifier() throws -> String {
        guard case let .identifier(name) = current.kind else {
            throw error("Expected an identifier.")
        }
        _ = advance()
        return name
    }

    private func error(_ message: String) -> ParseError {
        ParseError(message: message, line: current.line)
    }

    private mutating func parseStatements(
        stoppingAt stops: Set<Keyword>,
        context: ParseContext = .nested
    ) throws -> [Statement] {
        var statements: [Statement] = []
        while !isAtEnd {
            if case let .keyword(keyword) = current.kind, stops.contains(keyword) {
                break
            }
            if current.kind == .symbol(.underscore) {
                break
            }
            statements.append(try parseStatement(context: context))
        }
        return statements
    }

    private mutating func parseStatement(context: ParseContext) throws -> Statement {
        if match(.mut) {
            try expect(.val)
            return try parseValue(isMutable: true)
        }
        if match(.val) {
            return try parseValue(isMutable: false)
        }
        if match(.funcKeyword) {
            return try parseFunction()
        }
        if context == .topLevel, match(.mod) {
            let name = try expectIdentifier()
            let body = try parseStatements(stoppingAt: [.end])
            try expect(.end)
            return .module(name: name, body: body)
        }
        if context == .topLevel, current.kind == .keyword(.state) {
            _ = advance()
            let name = try expectIdentifier()
            let body = try parseStatements(stoppingAt: [.end])
            try expect(.end)
            return .state(name: name, body: body)
        }
        if match(.ifKeyword) {
            return try parseConditional()
        }
        if match(.whileKeyword) {
            let condition = try parseExpression()
            let body = try parseStatements(stoppingAt: [.end])
            try expect(.end)
            return .loop(condition: condition, body: body)
        }
        if match(.match) {
            return try parseMatch()
        }
        if match(.tryKeyword) {
            let body = try parseStatements(stoppingAt: [.catchKeyword])
            try expect(.catchKeyword)
            let errorName = try expectIdentifier()
            let handler = try parseStatements(stoppingAt: [.end])
            try expect(.end)
            return .attempt(body: body, errorName: errorName, handler: handler)
        }
        if match(.throwKeyword) {
            return .throwValue(try parseExpression())
        }
        if match(.print) {
            return .print(try parseExpression())
        }
        if match(.returnKeyword) {
            guard expressionCanStart(current.kind) else {
                return .returnValue(nil)
            }
            return .returnValue(try parseExpression())
        }
        if case let .identifier(name) = current.kind,
           peek().kind == .symbol(.equal) {
            _ = advance()
            _ = advance()
            return .assign(name: name, expression: try parseExpression())
        }
        if case .identifier = current.kind {
            let expression = try parseExpression()
            guard case .call = expression else {
                throw error("Only function calls can be used as expression statements.")
            }
            return .expression(expression)
        }
        if match(.state) {
            return .transition(to: try expectIdentifier())
        }
        throw error("Expected a statement.")
    }

    private mutating func parseValue(isMutable: Bool) throws -> Statement {
        let name = try expectIdentifier()
        try expect(.equal)
        return .value(name: name, isMutable: isMutable, expression: try parseExpression())
    }

    private mutating func parseFunction() throws -> Statement {
        let name = try expectIdentifier()
        try expect(.leftParenthesis)
        var parameters: [String] = []
        if !match(.rightParenthesis) {
            repeat {
                let parameter = try expectIdentifier()
                guard !parameters.contains(parameter) else {
                    throw error("Duplicate parameter '\(parameter)'.")
                }
                parameters.append(parameter)
            } while match(.comma)
            try expect(.rightParenthesis)
        }
        let body = try parseStatements(stoppingAt: [.end])
        try expect(.end)
        return .function(name: name, parameters: parameters, body: body)
    }

    private mutating func parseConditional() throws -> Statement {
        let condition = try parseExpression()
        let thenBody = try parseStatements(stoppingAt: [.elseKeyword, .end])
        let otherwise: [Statement]
        if match(.elseKeyword) {
            otherwise = try parseStatements(stoppingAt: [.end])
        } else {
            otherwise = []
        }
        try expect(.end)
        return .conditional(condition: condition, then: thenBody, otherwise: otherwise)
    }

    private mutating func parseMatch() throws -> Statement {
        let expression = try parseExpression()
        var cases: [(MatchPattern, [Statement])] = []
        var hasWildcard = false

        while !isAtEnd, current.kind != .keyword(.end) {
            let pattern: MatchPattern
            if match(.caseKeyword) {
                pattern = try parsePattern()
            } else if match(.underscore) {
                pattern = .wildcard
            } else {
                throw error("Expected 'case', '_' or 'end' in match.")
            }
            guard !hasWildcard else {
                throw error("The wildcard match case must be last.")
            }
            hasWildcard = pattern == .wildcard
            let body = try parseStatements(stoppingAt: [.caseKeyword, .end])
            cases.append((pattern, body))
            if hasWildcard || current.kind == .symbol(.underscore) {
                break
            }
        }

        if match(.underscore) {
            let body = try parseStatements(stoppingAt: [.end])
            cases.append((.wildcard, body))
        }
        try expect(.end)
        guard !cases.isEmpty else {
            throw error("A match statement requires at least one case.")
        }
        return .match(expression: expression, cases: cases)
    }

    private mutating func parsePattern() throws -> MatchPattern {
        return switch advance().kind {
        case let .numberLiteral(value): .number(value)
        case let .stringLiteral(value): .string(value)
        case .keyword(.trueKeyword): .boolean(true)
        case .keyword(.falseKeyword): .boolean(false)
        case .keyword(.trueTrileanKeyword): .trilean(.trueValue)
        case .keyword(.falseTrileanKeyword): .trilean(.falseValue)
        case .keyword(.unknownKeyword), .keyword(.lowercaseUnknownKeyword): .trilean(.unknown)
        case .keyword(.noneKeyword): .none
        case .symbol(.underscore): .wildcard
        default:
            position -= 1
            throw error("Expected a literal match pattern.")
        }
    }

    private mutating func parseExpression(minimumPrecedence: Int = 0) throws -> Expression {
        var expression = try parsePrefix()
        expression = try parsePostfix(expression)

        while let (operation, precedence) = binaryOperation(current.kind),
              precedence >= minimumPrecedence {
            _ = advance()
            let right = try parseExpression(minimumPrecedence: precedence + 1)
            expression = .binary(expression, operation, right)
        }
        return expression
    }

    private mutating func parsePrefix() throws -> Expression {
        if match(.not) {
            return .unary(.not, try parseExpression(minimumPrecedence: 7))
        }
        if match(.minus) {
            return .unary(.negate, try parseExpression(minimumPrecedence: 7))
        }
        let token = advance()
        if token.kind == .symbol(.leftParenthesis) {
            let expression = try parseExpression()
            try expect(.rightParenthesis)
            return expression
        }
        return switch token.kind {
        case let .numberLiteral(value): .number(value)
        case let .stringLiteral(value): .string(value)
        case .keyword(.trueKeyword): .boolean(true)
        case .keyword(.falseKeyword): .boolean(false)
        case .keyword(.trueTrileanKeyword): .trilean(.trueValue)
        case .keyword(.falseTrileanKeyword): .trilean(.falseValue)
        case .keyword(.unknownKeyword), .keyword(.lowercaseUnknownKeyword): .trilean(.unknown)
        case .keyword(.noneKeyword): .none
        case let .identifier(name): .variable(name)
        default:
            position -= 1
            throw error("Expected an expression.")
        }
    }

    private mutating func parsePostfix(_ initial: Expression) throws -> Expression {
        var expression = initial
        while true {
            if match(.dot) {
                expression = .member(expression, try expectIdentifier())
                continue
            }
            if match(.leftParenthesis) {
                var arguments: [Expression] = []
                if !match(.rightParenthesis) {
                    repeat {
                        arguments.append(try parseExpression())
                    } while match(.comma)
                    try expect(.rightParenthesis)
                }
                expression = .call(expression, arguments)
                continue
            }
            return expression
        }
    }

    private func binaryOperation(_ kind: TokenKind) -> (BinaryOperator, Int)? {
        guard case let .symbol(symbol) = kind else { return nil }
        return switch symbol {
        case .orOr: (.or, 1)
        case .andAnd: (.and, 2)
        case .equalEqual: (.equal, 3)
        case .notEqual: (.notEqual, 3)
        case .lessThan: (.lessThan, 4)
        case .lessThanOrEqual: (.lessThanOrEqual, 4)
        case .greaterThan: (.greaterThan, 4)
        case .greaterThanOrEqual: (.greaterThanOrEqual, 4)
        case .plus: (.add, 5)
        case .minus: (.subtract, 5)
        case .asterisk: (.multiply, 6)
        case .slash: (.divide, 6)
        default: nil
        }
    }

    private func expressionCanStart(_ kind: TokenKind) -> Bool {
        switch kind {
        case .numberLiteral, .stringLiteral, .identifier:
            true
        case .keyword(.trueKeyword), .keyword(.falseKeyword),
             .keyword(.trueTrileanKeyword), .keyword(.falseTrileanKeyword),
             .keyword(.unknownKeyword), .keyword(.lowercaseUnknownKeyword), .keyword(.noneKeyword):
            true
        case .symbol(.leftParenthesis), .symbol(.not), .symbol(.minus):
            true
        default:
            false
        }
    }

    private enum ParseContext: Equatable {
        case topLevel
        case nested
    }
}
