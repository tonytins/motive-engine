import Foundation

/// A Robusta instruction encoded as a variable-length JSON array.
public enum Instruction: Sendable, Equatable {
    case pushNumber(Double)
    case pushBoolean(Bool)
    case pushTrilean(Trilean)
    case pushString(String)
    case pushNone
    case load(String)
    case store(String)
    case storeMutable(String)
    case assign(String)
    case negate
    case not
    case add
    case subtract
    case multiply
    case divide
    case equal
    case notEqual
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual
    case and
    case or
    case call(String, argumentCount: Int)
    case discard
    case print
    case conditional(
        condition: [Instruction],
        then: [Instruction],
        otherwise: [Instruction]
    )
    case loop(condition: [Instruction], body: [Instruction])
    case match(expression: [Instruction], cases: [(MatchPattern, [Instruction])])
    case attempt(body: [Instruction], errorName: String, handler: [Instruction])
    case throwError
    case `return`(hasValue: Bool)
    case function(name: String, parameters: [String], body: [Instruction])
    case module(name: String, body: [Instruction])
    case stateDeclaration(name: String, body: [Instruction])
    case transition(to: String)

    public static func == (lhs: Instruction, rhs: Instruction) -> Bool {
        switch (lhs, rhs) {
        case let (.pushNumber(l), .pushNumber(r)): l == r
        case let (.pushBoolean(l), .pushBoolean(r)): l == r
        case let (.pushTrilean(l), .pushTrilean(r)): l == r
        case let (.pushString(l), .pushString(r)): l == r
        case (.pushNone, .pushNone), (.negate, .negate), (.not, .not),
             (.add, .add), (.subtract, .subtract), (.multiply, .multiply),
             (.divide, .divide), (.equal, .equal), (.notEqual, .notEqual),
             (.lessThan, .lessThan), (.lessThanOrEqual, .lessThanOrEqual),
             (.greaterThan, .greaterThan), (.greaterThanOrEqual, .greaterThanOrEqual),
             (.and, .and), (.or, .or), (.discard, .discard), (.print, .print),
             (.throwError, .throwError):
            true
        case let (.load(l), .load(r)), let (.store(l), .store(r)),
             let (.storeMutable(l), .storeMutable(r)), let (.assign(l), .assign(r)),
             let (.transition(l), .transition(r)):
            l == r
        case let (.call(ln, lc), .call(rn, rc)):
            ln == rn && lc == rc
        case let (.conditional(lc, lt, lo), .conditional(rc, rt, ro)):
            lc == rc && lt == rt && lo == ro
        case let (.loop(lc, lb), .loop(rc, rb)):
            lc == rc && lb == rb
        case let (.match(le, lc), .match(re, rc)):
            le == re && lc.elementsEqual(rc, by: ==)
        case let (.attempt(lb, ln, lh), .attempt(rb, rn, rh)):
            lb == rb && ln == rn && lh == rh
        case let (.return(l), .return(r)):
            l == r
        case let (.function(ln, lp, lb), .function(rn, rp, rb)):
            ln == rn && lp == rp && lb == rb
        case let (.module(ln, lb), .module(rn, rb)):
            ln == rn && lb == rb
        case let (.stateDeclaration(ln, lb), .stateDeclaration(rn, rb)):
            ln == rn && lb == rb
        default:
            false
        }
    }

    /// Compatibility factory for the original state declaration case.
    public static func state(name: String, body: [Instruction]) -> Instruction {
        .stateDeclaration(name: name, body: body)
    }
}

extension Instruction: Codable {
    private enum Opcode: String {
        case pushNumber = "push_num"
        case pushBoolean = "push_bool"
        case pushTrilean = "push_trilean"
        case pushString = "push_string"
        case pushNone = "push_none"
        case load
        case store
        case storeMutable = "store_mut"
        case assign
        case negate
        case not
        case add
        case subtract = "sub"
        case multiply = "mul"
        case divide = "div"
        case equal = "eq"
        case notEqual = "neq"
        case lessThan = "lt"
        case lessThanOrEqual = "lte"
        case greaterThan = "gt"
        case greaterThanOrEqual = "gte"
        case and
        case or
        case call
        case discard = "drop"
        case print
        case conditional = "if"
        case loop = "while"
        case match
        case attempt = "try"
        case throwError = "throw"
        case `return`
        case function = "func"
        case module = "mod"
        case stateDeclaration = "state_decl"
        case transition = "state"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .pushNumber(value):
            try container.encode(Opcode.pushNumber.rawValue)
            try container.encode(value)
        case let .pushBoolean(value):
            try container.encode(Opcode.pushBoolean.rawValue)
            try container.encode(value)
        case let .pushTrilean(value):
            try container.encode(Opcode.pushTrilean.rawValue)
            try container.encode(value.rawValue)
        case let .pushString(value):
            try container.encode(Opcode.pushString.rawValue)
            try container.encode(value)
        case .pushNone:
            try container.encode(Opcode.pushNone.rawValue)
        case let .load(name):
            try container.encode(Opcode.load.rawValue)
            try container.encode(name)
        case let .store(name):
            try container.encode(Opcode.store.rawValue)
            try container.encode(name)
        case let .storeMutable(name):
            try container.encode(Opcode.storeMutable.rawValue)
            try container.encode(name)
        case let .assign(name):
            try container.encode(Opcode.assign.rawValue)
            try container.encode(name)
        case .negate:
            try container.encode(Opcode.negate.rawValue)
        case .not:
            try container.encode(Opcode.not.rawValue)
        case .add:
            try container.encode(Opcode.add.rawValue)
        case .subtract:
            try container.encode(Opcode.subtract.rawValue)
        case .multiply:
            try container.encode(Opcode.multiply.rawValue)
        case .divide:
            try container.encode(Opcode.divide.rawValue)
        case .equal:
            try container.encode(Opcode.equal.rawValue)
        case .notEqual:
            try container.encode(Opcode.notEqual.rawValue)
        case .lessThan:
            try container.encode(Opcode.lessThan.rawValue)
        case .lessThanOrEqual:
            try container.encode(Opcode.lessThanOrEqual.rawValue)
        case .greaterThan:
            try container.encode(Opcode.greaterThan.rawValue)
        case .greaterThanOrEqual:
            try container.encode(Opcode.greaterThanOrEqual.rawValue)
        case .and:
            try container.encode(Opcode.and.rawValue)
        case .or:
            try container.encode(Opcode.or.rawValue)
        case let .call(name, count):
            try container.encode(Opcode.call.rawValue)
            try container.encode(name)
            try container.encode(count)
        case .print:
            try container.encode(Opcode.print.rawValue)
        case .discard:
            try container.encode(Opcode.discard.rawValue)
        case let .conditional(condition, then, otherwise):
            try container.encode(Opcode.conditional.rawValue)
            try container.encode(condition)
            try container.encode(InstructionBranch(tag: "then", body: then))
            try container.encode(InstructionBranch(tag: "else", body: otherwise))
        case let .loop(condition, body):
            try container.encode(Opcode.loop.rawValue)
            try container.encode(condition)
            try container.encode(body)
        case let .match(expression, cases):
            try container.encode(Opcode.match.rawValue)
            try container.encode(expression)
            try container.encode(cases.map { MatchInstructionCase(pattern: $0.0, body: $0.1) })
        case let .attempt(body, errorName, handler):
            try container.encode(Opcode.attempt.rawValue)
            try container.encode(body)
            try container.encode(CatchInstructionBlock(errorName: errorName, body: handler))
        case .throwError:
            try container.encode(Opcode.throwError.rawValue)
        case let .return(hasValue):
            try container.encode(Opcode.return.rawValue)
            try container.encode(hasValue)
        case let .function(name, parameters, body):
            try container.encode(Opcode.function.rawValue)
            try container.encode(name)
            try container.encode(parameters)
            try container.encode(body)
        case let .module(name, body):
            try container.encode(Opcode.module.rawValue)
            try container.encode(name)
            try container.encode(body)
        case let .stateDeclaration(name, body):
            try container.encode(Opcode.stateDeclaration.rawValue)
            try container.encode(name)
            try container.encode(body)
        case let .transition(name):
            try container.encode(Opcode.transition.rawValue)
            try container.encode(name)
        }
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let rawOpcode = try container.decode(String.self)
        guard let opcode = Opcode(rawValue: rawOpcode) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown Robusta instruction '\(rawOpcode)'."
            )
        }

        switch opcode {
        case .pushNumber:
            self = .pushNumber(try container.decode(Double.self))
        case .pushBoolean:
            self = .pushBoolean(try container.decode(Bool.self))
        case .pushTrilean:
            let spelling = try container.decode(String.self)
            guard let value = Trilean(rawValue: spelling) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown Trilean literal '\(spelling)'."
                )
            }
            self = .pushTrilean(value)
        case .pushString:
            self = .pushString(try container.decode(String.self))
        case .pushNone:
            self = .pushNone
        case .load:
            self = .load(try container.decode(String.self))
        case .store:
            self = .store(try container.decode(String.self))
        case .storeMutable:
            self = .storeMutable(try container.decode(String.self))
        case .assign:
            self = .assign(try container.decode(String.self))
        case .negate:
            self = .negate
        case .not:
            self = .not
        case .add:
            self = .add
        case .subtract:
            self = .subtract
        case .multiply:
            self = .multiply
        case .divide:
            self = .divide
        case .equal:
            self = .equal
        case .notEqual:
            self = .notEqual
        case .lessThan:
            self = .lessThan
        case .lessThanOrEqual:
            self = .lessThanOrEqual
        case .greaterThan:
            self = .greaterThan
        case .greaterThanOrEqual:
            self = .greaterThanOrEqual
        case .and:
            self = .and
        case .or:
            self = .or
        case .call:
            let name = try container.decode(String.self)
            let count = try container.decode(Int.self)
            guard count >= 0 else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "A call argument count cannot be negative."
                )
            }
            self = .call(name, argumentCount: count)
        case .print:
            self = .print
        case .discard:
            self = .discard
        case .conditional:
            let condition = try container.decode([Instruction].self)
            let then = try container.decode(InstructionBranch.self)
            let otherwise = try container.decode(InstructionBranch.self)
            guard then.tag == "then", otherwise.tag == "else" else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "An 'if' instruction requires ordered then and else blocks."
                )
            }
            self = .conditional(
                condition: condition,
                then: then.body,
                otherwise: otherwise.body
            )
        case .loop:
            self = .loop(
                condition: try container.decode([Instruction].self),
                body: try container.decode([Instruction].self)
            )
        case .match:
            let expression = try container.decode([Instruction].self)
            let cases = try container.decode([MatchInstructionCase].self)
            guard !cases.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "A 'match' instruction requires at least one case."
                )
            }
            let wildcardIndices = cases.indices.filter { cases[$0].pattern == .wildcard }
            guard wildcardIndices.count <= 1,
                  wildcardIndices.first.map({ $0 == cases.count - 1 }) ?? true else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "A match wildcard must be the final, unique case."
                )
            }
            self = .match(expression: expression, cases: cases.map { ($0.pattern, $0.body) })
        case .attempt:
            let body = try container.decode([Instruction].self)
            let catchBlock = try container.decode(CatchInstructionBlock.self)
            self = .attempt(
                body: body,
                errorName: catchBlock.errorName,
                handler: catchBlock.body
            )
        case .throwError:
            self = .throwError
        case .return:
            self = .return(hasValue: try container.decode(Bool.self))
        case .function:
            self = .function(
                name: try container.decode(String.self),
                parameters: try container.decode([String].self),
                body: try container.decode([Instruction].self)
            )
        case .module:
            self = .module(
                name: try container.decode(String.self),
                body: try container.decode([Instruction].self)
            )
        case .stateDeclaration:
            self = .stateDeclaration(
                name: try container.decode(String.self),
                body: try container.decode([Instruction].self)
            )
        case .transition:
            self = .transition(to: try container.decode(String.self))
        }

        guard container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected extra values in Robusta instruction '\(rawOpcode)'."
            )
        }
    }
}

private struct MatchInstructionCase: Codable {
    let pattern: MatchPattern
    let body: [Instruction]

    init(pattern: MatchPattern, body: [Instruction]) {
        self.pattern = pattern
        self.body = body
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let tag = try container.decode(String.self)
        if tag == "_" {
            pattern = .wildcard
        } else {
            guard tag == "case" else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "A match arm must start with 'case' or '_'."
                )
            }
            pattern = try container.decode(MatchPattern.self)
        }
        body = try container.decode([Instruction].self)
        guard container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected extra values in match arm."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        if pattern == .wildcard {
            try container.encode("_")
        } else {
            try container.encode("case")
            try container.encode(pattern)
        }
        try container.encode(body)
    }
}

private struct InstructionBranch: Codable {
    let tag: String
    let body: [Instruction]

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(tag)
        try container.encode(body)
    }

    init(tag: String, body: [Instruction]) {
        self.tag = tag
        self.body = body
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        tag = try container.decode(String.self)
        body = try container.decode([Instruction].self)
        guard container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected extra values in instruction block."
            )
        }
    }
}

private struct CatchInstructionBlock: Codable {
    let errorName: String
    let body: [Instruction]

    init(errorName: String, body: [Instruction]) {
        self.errorName = errorName
        self.body = body
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode("catch")
        try container.encode(errorName)
        try container.encode(body)
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let tag = try container.decode(String.self)
        guard tag == "catch" else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "A 'try' instruction must contain a catch block."
            )
        }
        errorName = try container.decode(String.self)
        body = try container.decode([Instruction].self)
        guard container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected extra values in catch block."
            )
        }
    }
}

extension Trilean {
    fileprivate var rawValue: String {
        switch self {
        case .trueValue: "true"
        case .falseValue: "false"
        case .unknown: "unknown"
        }
    }

    fileprivate init?(rawValue: String) {
        switch rawValue {
        case "true": self = .trueValue
        case "false": self = .falseValue
        case "unknown", "Unknown": self = .unknown
        default: return nil
        }
    }
}

extension MatchPattern: Codable {
    private enum Tag: String, Codable {
        case boolean
        case trilean
        case number
        case string
        case none
        case wildcard
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case let .boolean(value):
            try container.encode(Tag.boolean)
            try container.encode(value)
        case let .trilean(value):
            try container.encode(Tag.trilean)
            try container.encode(value.rawValue)
        case let .number(value):
            try container.encode(Tag.number)
            try container.encode(value)
        case let .string(value):
            try container.encode(Tag.string)
            try container.encode(value)
        case .none:
            try container.encode(Tag.none)
        case .wildcard:
            try container.encode(Tag.wildcard)
        }
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let tag = try container.decode(Tag.self)
        switch tag {
        case .boolean:
            self = .boolean(try container.decode(Bool.self))
        case .trilean:
            let spelling = try container.decode(String.self)
            guard let value = Trilean(rawValue: spelling) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown Trilean pattern '\(spelling)'."
                )
            }
            self = .trilean(value)
        case .number:
            self = .number(try container.decode(Double.self))
        case .string:
            self = .string(try container.decode(String.self))
        case .none:
            self = .none
        case .wildcard:
            self = .wildcard
        }
        guard container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected extra values in match pattern."
            )
        }
    }
}
