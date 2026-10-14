import Foundation

/// Compiles Robusta syntax into JSON intermediate representation.
public enum RobustaCompiler {
    /// Parses source with the supplied frontend and returns its JSON IR.
    public static func compile(_ source: String, using frontend: any Frontend) throws -> Data {
        let statements = try frontend.parse(source)
        return try JSONEncoder().encode(lower(statements: statements))
    }

    static func lower(statements: [Statement]) -> [Instruction] {
        statements.flatMap(lower)
    }

    static func decode(ir: Data) throws -> [Instruction] {
        try JSONDecoder().decode([Instruction].self, from: ir)
    }

    private static func lower(_ statement: Statement) -> [Instruction] {
        switch statement {
        case let .value(name, isMutable, expression):
            return lower(expression) + [isMutable ? .storeMutable(name) : .store(name)]
        case let .assign(name, expression):
            return lower(expression) + [.assign(name)]
        case let .expression(expression):
            return lower(expression) + [.discard]
        case let .print(expression):
            return lower(expression) + [.print]
        case let .function(name, parameters, body):
            return [.function(name: name, parameters: parameters, body: lower(statements: body))]
        case let .module(name, body):
            return [.module(name: name, body: lower(statements: body))]
        case let .state(name, body):
            return [.stateDeclaration(name: name, body: lower(statements: body))]
        case let .transition(to):
            return [.transition(to: to)]
        case let .conditional(condition, then, otherwise):
            return [.conditional(
                condition: lower(condition),
                then: lower(statements: then),
                otherwise: lower(statements: otherwise)
            )]
        case let .loop(condition, body):
            return [.loop(condition: lower(condition), body: lower(statements: body))]
        case let .match(expression, cases):
            return [.match(
                expression: lower(expression),
                cases: cases.map { ($0.0, lower(statements: $0.1)) }
            )]
        case let .attempt(body, errorName, handler):
            return [.attempt(
                body: lower(statements: body),
                errorName: errorName,
                handler: lower(statements: handler)
            )]
        case let .throwValue(expression):
            return lower(expression) + [.throwError]
        case let .returnValue(expression):
            var instructions = expression.map(lower) ?? []
            instructions.append(.return(hasValue: expression != nil))
            return instructions
        }
    }

    private static func lower(_ expression: Expression) -> [Instruction] {
        switch expression {
        case let .number(value):
            [.pushNumber(value)]
        case let .boolean(value):
            [.pushBoolean(value)]
        case let .trilean(value):
            [.pushTrilean(value)]
        case let .string(value):
            [.pushString(value)]
        case .none:
            [.pushNone]
        case let .variable(name):
            [.load(name)]
        case let .member(base, name):
            [.load(memberPath(base, appending: name))]
        case let .call(callee, arguments):
            arguments.flatMap(lower) + [.call(callableName(callee), argumentCount: arguments.count)]
        case let .unary(operation, operand):
            lower(operand) + [operation == .not ? .not : .negate]
        case let .binary(left, operation, right):
            lower(left) + lower(right) + [instruction(for: operation)]
        }
    }

    private static func memberPath(_ base: Expression, appending member: String) -> String {
        switch base {
        case let .variable(name): "\(name).\(member)"
        case let .member(parent, name): "\(memberPath(parent, appending: name)).\(member)"
        default: "\(String(describing: base)).\(member)"
        }
    }

    private static func callableName(_ expression: Expression) -> String {
        switch expression {
        case let .variable(name): name
        case let .member(base, member): memberPath(base, appending: member)
        default: ""
        }
    }

    private static func instruction(for operation: BinaryOperator) -> Instruction {
        switch operation {
        case .add: .add
        case .subtract: .subtract
        case .multiply: .multiply
        case .divide: .divide
        case .equal: .equal
        case .notEqual: .notEqual
        case .lessThan: .lessThan
        case .lessThanOrEqual: .lessThanOrEqual
        case .greaterThan: .greaterThan
        case .greaterThanOrEqual: .greaterThanOrEqual
        case .and: .and
        case .or: .or
        }
    }
}

/// Executes Robusta programs and returns lines written by `print`.
public enum RobustaVM {
    /// Runs source through parsing, validation, JSON IR, and execution.
    public static func run(
        _ source: String,
        using frontend: any Frontend = RobustaFrontend()
    ) throws -> [String] {
        let statements = try frontend.parse(source)
        try ProgramValidator.validate(statements)
        let ir = try JSONEncoder().encode(RobustaCompiler.lower(statements: statements))
        return try run(ir: ir)
    }

    static func run(_ statements: [Statement]) throws -> [String] {
        try ProgramValidator.validate(statements)
        let instructions = RobustaCompiler.lower(statements: statements)
        var interpreter = Interpreter(instructions: instructions)
        return try interpreter.run()
    }

    static func run(ir: Data) throws -> [String] {
        let instructions = try RobustaCompiler.decode(ir: ir)
        var interpreter = Interpreter(instructions: instructions)
        return try interpreter.run()
    }
}

public struct ProgramError: Error, Equatable, Sendable, CustomStringConvertible {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var description: String { message }
}

private enum ProgramValidator {
    static func validate(_ statements: [Statement]) throws {
        let states = statements.compactMap { statement -> (String, [Statement])? in
            guard case let .state(name, body) = statement else { return nil }
            return (name, body)
        }
        guard states.contains(where: { $0.0 == "default" }) else {
            throw ProgramError(message: "A Robusta program must declare a 'default' state.")
        }
        guard Set(states.map(\.0)).count == states.count else {
            throw ProgramError(message: "State names must be unique.")
        }

        guard let defaultState = states.first(where: { $0.0 == "default" }) else {
            throw ProgramError(message: "A Robusta program must declare a 'default' state.")
        }
        guard case let .function(_, entryParameters, _)? = defaultState.1.first(where: {
            if case let .function(name, _, _) = $0 { return name == "stateEntry" }
            return false
        }) else {
            throw ProgramError(message: "The 'default' state must define stateEntry().")
        }
        guard entryParameters.isEmpty else {
            throw ProgramError(message: "The 'default' state's stateEntry() must not take parameters.")
        }

        for (name, body) in states {
            var handlerNames: Set<String> = []
            for statement in body {
                guard case let .function(handler, parameters, functionBody) = statement else {
                    throw ProgramError(message: "State '\(name)' can contain only function declarations.")
                }
                guard handlerNames.insert(handler).inserted else {
                    throw ProgramError(
                        message: "Handler '\(handler)' is declared more than once in state '\(name)'."
                    )
                }
                guard Set(parameters).count == parameters.count else {
                    throw ProgramError(message: "Handler '\(handler)' has duplicate parameters.")
                }
                if handler == "stateExit", !parameters.isEmpty {
                    throw ProgramError(message: "stateExit() in state '\(name)' must not take parameters.")
                }
                try validateExecutableBody(functionBody)
            }
        }

        try validateFunctionNames(in: statements, namespace: nil)
        let stateNames = Set(states.map(\.0))
        try validateTransitions(in: statements, stateNames: stateNames)
    }

    private static func validateFunctionNames(
        in statements: [Statement],
        namespace: String?
    ) throws {
        var names: Set<String> = []
        var moduleNames: Set<String> = []
        for statement in statements {
            switch statement {
            case let .function(name, _, body):
                let qualifiedName = namespace.map { "\($0).\(name)" } ?? name
                guard names.insert(qualifiedName).inserted else {
                    throw ProgramError(message: "Function '\(qualifiedName)' is declared more than once.")
                }
                guard case let .function(_, parameters, _) = statement,
                      Set(parameters).count == parameters.count else {
                    throw ProgramError(message: "Function '\(qualifiedName)' has duplicate parameters.")
                }
                try validateExecutableBody(body)
            case let .module(name, body):
                guard moduleNames.insert(name).inserted else {
                    throw ProgramError(message: "Module '\(name)' is declared more than once.")
                }
                guard body.allSatisfy({
                    if case .function = $0 { return true }
                    return false
                }) else {
                    throw ProgramError(message: "Module '\(name)' can contain only function declarations.")
                }
                try validateFunctionNames(in: body, namespace: namespace.map { "\($0).\(name)" } ?? name)
            case let .state(_, body):
                try validateFunctionNames(in: body, namespace: namespace)
            case let .conditional(_, then, otherwise):
                try validateExecutableBody(then)
                try validateExecutableBody(otherwise)
            case let .loop(_, body):
                try validateExecutableBody(body)
            case let .match(_, cases):
                try validateCases(cases)
                for (_, body) in cases {
                    try validateExecutableBody(body)
                }
            case let .attempt(body, _, handler):
                try validateExecutableBody(body)
                try validateExecutableBody(handler)
            case .value, .assign, .expression, .print, .transition, .throwValue, .returnValue:
                break
            }
        }
    }

    private static func validateExecutableBody(_ statements: [Statement]) throws {
        for statement in statements {
            switch statement {
            case .function, .module, .state:
                throw ProgramError(
                    message: "Function, module, and state declarations are allowed only at top level or in their enclosing declaration."
                )
            case let .conditional(_, then, otherwise):
                try validateExecutableBody(then)
                try validateExecutableBody(otherwise)
            case let .loop(_, body):
                try validateExecutableBody(body)
            case let .match(_, cases):
                try validateCases(cases)
                for (_, body) in cases {
                    try validateExecutableBody(body)
                }
            case let .attempt(body, _, handler):
                try validateExecutableBody(body)
                try validateExecutableBody(handler)
            case .value, .assign, .expression, .print, .transition, .throwValue, .returnValue:
                break
            }
        }
    }

    private static func validateCases(
        _ cases: [(MatchPattern, [Statement])]
    ) throws {
        guard !cases.isEmpty else {
            throw ProgramError(message: "A match statement requires at least one case.")
        }
        let wildcardIndices = cases.indices.filter { cases[$0].0 == .wildcard }
        guard wildcardIndices.count <= 1,
              wildcardIndices.first.map({ $0 == cases.count - 1 }) ?? true else {
            throw ProgramError(message: "A match wildcard must be the final, unique case.")
        }
    }

    private static func validateTransitions(
        in statements: [Statement],
        stateNames: Set<String>
    ) throws {
        for statement in statements {
            switch statement {
            case let .transition(name):
                guard stateNames.contains(name) else {
                    throw ProgramError(message: "Transition targets undeclared state '\(name)'.")
                }
            case let .function(_, _, body), let .module(_, body), let .state(_, body),
                 let .loop(_, body), let .attempt(body, _, _):
                try validateTransitions(in: body, stateNames: stateNames)
                if case let .attempt(_, _, handler) = statement {
                    try validateTransitions(in: handler, stateNames: stateNames)
                }
            case let .conditional(_, then, otherwise):
                try validateTransitions(in: then, stateNames: stateNames)
                try validateTransitions(in: otherwise, stateNames: stateNames)
            case let .match(_, cases):
                for (_, body) in cases {
                    try validateTransitions(in: body, stateNames: stateNames)
                }
            case .value, .assign, .expression, .print, .throwValue, .returnValue:
                break
            }
        }
    }
}
