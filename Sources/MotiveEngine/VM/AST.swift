import Foundation

enum Opcode: String, CaseIterable {
    case number, boolean, none
    case variable, hasModifier, not, negate
    case add, sub, mul, div, and, or, eq, neq, lt, gt, lte, gte
    case wildcard, modifierName
    case val, assign, emit, match, matchModifier
}

enum BinaryOperator: String, CaseIterable {
    case add, sub, mul, div, and, or, eq, neq, lt, gt, lte, gte

    init?(symbol: String) {
        switch symbol {
        case "+": self = .add
        case "-": self = .sub
        case "*": self = .mul
        case "/": self = .div
        case "and": self = .and
        case "or": self = .or
        case "=": self = .eq
        case "<>": self = .neq
        case "<": self = .lt
        case ">": self = .gt
        case "<=": self = .lte
        case ">=": self = .gte
        default: return nil
        }
    }

    var symbol: String {
        switch self {
        case .add: "+"
        case .sub: "-"
        case .mul: "*"
        case .div: "/"
        case .and: "and"
        case .or: "or"
        case .eq: "="
        case .neq: "<>"
        case .lt: "<"
        case .gt: ">"
        case .lte: "<="
        case .gte: ">="
        }
    }
}

enum Pattern: Equatable {
    case boolean(Bool)
    case number(Double)
    case none
    case wildcard
}

enum Stmt {
    case val(name: String, isMutable: Bool, value: Expr, line: Int)
    case assign(name: String, value: Expr, line: Int)
    case emit(motive: MotiveType, value: Expr, line: Int)
    case match(scrutinee: Expr, arms: [MatchArm], line: Int)
    case transition(state: String, line: Int)
}

struct MatchArm {
    let pattern: Pattern
    let body: [Stmt]
    let line: Int
}

struct FuncDecl {
    let name: String
    let body: [Stmt]
    let line: Int
}

struct StateDecl {
    let name: String
    /// let functions: [FuncDecl]
    let line: Int
}

extension StateDecl: Codable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(name)
        // try container.encode(functions)
        try container.encode(line)
    }

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        name = try container.decode(String.self)
        // functions = try container.decode([FuncDecl].self)
        line = try container.decode(Int.self)
    }
}

indirect enum Expr {
    case number(Double)
    case boolean(Bool)
    case none
    case variable(String, line: Int)
    case hasModifier(String, line: Int)
    case not(Expr, line: Int)
    case unaryMinus(Expr, line: Int)
    case binary(Expr, BinaryOperator, Expr, line: Int)
}

extension Expr: Codable {
    static let binaryOperators: Set<String> = [
        "+", "-", "*", "/", "%", "==",
        "!=", "<", ">", "<=", ">=",
    ]

    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .number(value):
            try container.encode(Opcode.number.rawValue)
            try container.encode(value)
        case let .boolean(value):
            try container.encode(Opcode.boolean.rawValue)
            try container.encode(value)
        case let .variable(name, line):
            try container.encode(Opcode.variable.rawValue)
            try container.encode(name)
            try container.encode(line)
        case let .binary(left, op, right, line):
            try container.encode(op.rawValue)
            try container.encode(left)
            try container.encode(right)
        case .none:
            break
        case let .hasModifier(_, line: line):
            break
        case let .not(_, line: line):
            break
        case let .unaryMinus(_, line: line):
            break
        }
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let tag = try container.decode(String.self)
        switch Opcode(rawValue: tag) {
        default:
            throw DecodingError
                .dataCorruptedError(in: container, debugDescription: "Unknown expression tag '\(tag)'")
        }
    }
}
