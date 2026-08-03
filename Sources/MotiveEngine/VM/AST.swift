import Foundation

private enum Opcode: String, CaseIterable, Sendable {
    case number, boolean, none
    case variable, hasModifier, not, negate
    case add, sub, mul, div, and, or, eq, neq, lt, gt, lte, gte
    case wildcard, modifierName
    case val, assign, emit, match, matchModifier
}

private enum BinaryOperator: String, CaseIterable, Sendable {
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
        case .add: return "+"
        case .sub: return "-"
        case .mul: return "*"
        case .div: return "/"
        case .and: return "and"
        case .or: return "or"
        case .eq: return "="
        case .neq: return "<>"
        case .lt: return "<"
        case .gt: return ">"
        case .lte: return "<="
        case .gte: return ">="
        }
    }
}

private indirect enum Expr: Sendable {
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
    
    static let binaryOperators: Set<String> = ["+", "-", "*", "/", "%", "==", "!=", "<", ">", "<=", ">="]
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .number(let value):
            try container.encode(Opcode.number.rawValue)
            try container.encode(value)
        case .boolean(let value):
            try container.encode(Opcode.boolean.rawValue)
            try container.encode(value)
        case .variable(let name, let line):
            try container.encode(Opcode.variable.rawValue)
            try container.encode(name)
            try container.encode(line)
        case .binary(let left, let op, let right, let line):
            try container.encode(op.rawValue)
            try container.encode(left)
            try container.encode(right)
        case .none:
            break
        case .hasModifier(_, line: let line):
            break
        case .not(_, line: let line):
            break
        case .unaryMinus(_, line: let line):
            break
        }
    }
    
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let tag = try container.decode(String.self)
        switch Opcode(rawValue: tag) {
        default:
            throw DecodingError
                .dataCorruptedError(in: container, debugDescription: "Unknown expression tag '\(tag)'")
        }
    }
}
