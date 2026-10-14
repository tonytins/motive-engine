import Foundation

/// A failure while running a Robusta program, including thrown values and
/// the instruction limit.
public struct RuntimeError: Error, Equatable, Sendable, CustomStringConvertible {
    /// A description of the problem.
    public let message: String

    /// Creates an error with a message.
    public init(message: String) {
        self.message = message
    }

    /// The message.
    public var description: String { message }
}

/// A plain value passed across the Robusta host boundary.
enum HostValue: Equatable, Sendable {
    case number(Double)
    case boolean(Bool)
    case trilean(Trilean)
    case string(String)
    case none
}

/// A call a script made to a host-declared function, in call order.
struct HostCall: Equatable, Sendable {
    let name: String
    let arguments: [HostValue]
}

private enum RuntimeValue {
    case number(Double)
    case boolean(Bool)
    case trilean(Trilean)
    case string(String)
    case none
    case reference(RuntimeReference)

    var resolved: RuntimeValue {
        if case let .reference(reference) = self {
            return reference.value.resolved
        }
        return self
    }

    var displayValue: String {
        switch resolved {
        case let .number(number):
            if number.isFinite, number.rounded(.towardZero) == number {
                return String(format: "%.0f", number)
            }
            return String(number)
        case let .boolean(value):
            return String(value)
        case let .trilean(value):
            switch value {
            case .trueValue: return "true"
            case .falseValue: return "false"
            case .unknown: return "unknown"
            }
        case let .string(value):
            return value
        case .none:
            return "None"
        case let .reference(reference):
            return reference.value.displayValue
        }
    }

    init(_ hostValue: HostValue) {
        switch hostValue {
        case let .number(value): self = .number(value)
        case let .boolean(value): self = .boolean(value)
        case let .trilean(value): self = .trilean(value)
        case let .string(value): self = .string(value)
        case .none: self = .none
        }
    }

    var hostValue: HostValue {
        switch resolved {
        case let .number(value): .number(value)
        case let .boolean(value): .boolean(value)
        case let .trilean(value): .trilean(value)
        case let .string(value): .string(value)
        case .none, .reference: .none
        }
    }

    var typeName: String {
        switch resolved {
        case .number: "number"
        case .boolean: "Bool"
        case .trilean: "Trilean"
        case .string: "string"
        case .none: "None"
        case let .reference(reference): reference.value.typeName
        }
    }
}

private final class RuntimeReference {
    var value: RuntimeValue

    init(value: RuntimeValue) {
        self.value = value.resolved
    }
}

private struct RuntimeFunction {
    let name: String
    let parameters: [String]
    let body: [Instruction]
    let namespace: String?
}

private final class RuntimeBinding {
    let isMutableReference: Bool
    let reference: RuntimeReference

    init(value: RuntimeValue, isMutableReference: Bool) {
        if case let .reference(reference) = value {
            self.reference = reference
        } else {
            self.reference = RuntimeReference(value: value)
        }
        self.isMutableReference = isMutableReference
    }

    var value: RuntimeValue {
        .reference(reference)
    }
}

private enum ExecutionSignal {
    case complete
    case returned(RuntimeValue)
    case transitioned(String)
}

struct Interpreter {
    private let instructions: [Instruction]
    private let hostFunctions: [String: Int]
    private(set) var hostCalls: [HostCall] = []
    private var stack: [RuntimeValue] = []
    private var globals: [String: RuntimeBinding] = [:]
    private var scopes: [[String: RuntimeBinding]] = []
    private var functions: [String: RuntimeFunction] = [:]
    private var states: [String: [String: RuntimeFunction]] = [:]
    private var output: [String] = []
    private var currentNamespace: String?
    private var currentState: String?
    private var executedInstructions = 0
    private var callDepth = 0
    private let instructionLimit = 100_000
    private let callDepthLimit = 256

    /// Creates an interpreter with optional host inputs and functions.
    ///
    /// Host values become immutable globals. Host functions are declared by
    /// qualified name and arity; calls are recorded in `hostCalls` and
    /// return `None`.
    init(
        instructions: [Instruction],
        hostValues: [String: HostValue] = [:],
        hostFunctions: [String: Int] = [:]
    ) {
        self.instructions = instructions
        self.hostFunctions = hostFunctions
        for (name, value) in hostValues {
            globals[name] = RuntimeBinding(value: RuntimeValue(value), isMutableReference: false)
        }
    }

    mutating func run() throws -> [String] {
        try registerDeclarations(instructions, namespace: nil)
        try executeTopLevel(instructions)
        try runInitialState()
        return output
    }

    private mutating func registerDeclarations(
        _ instructions: [Instruction],
        namespace: String?
    ) throws {
        for instruction in instructions {
            switch instruction {
            case let .function(name, parameters, body):
                let qualifiedName = namespace.map { "\($0).\(name)" } ?? name
                guard functions[qualifiedName] == nil else {
                    throw RuntimeError(message: "Function '\(qualifiedName)' is declared more than once.")
                }
                guard hostFunctions[qualifiedName] == nil else {
                    throw RuntimeError(message: "Function '\(qualifiedName)' is reserved by the host.")
                }
                guard Set(parameters).count == parameters.count else {
                    throw RuntimeError(message: "Function '\(qualifiedName)' has duplicate parameters.")
                }
                functions[qualifiedName] = RuntimeFunction(
                    name: qualifiedName,
                    parameters: parameters,
                    body: body,
                    namespace: namespace
                )
            case let .module(name, body):
                try registerDeclarations(body, namespace: namespace.map { "\($0).\(name)" } ?? name)
            case let .stateDeclaration(name, body):
                guard states[name] == nil else {
                    throw RuntimeError(message: "State '\(name)' is declared more than once.")
                }
                var handlers: [String: RuntimeFunction] = [:]
                for statement in body {
                    guard case let .function(handlerName, parameters, handlerBody) = statement else {
                        throw RuntimeError(
                            message: "State '\(name)' can contain only function declarations."
                        )
                    }
                    guard handlers[handlerName] == nil else {
                        throw RuntimeError(
                            message: "Handler '\(handlerName)' is declared more than once in state '\(name)'."
                        )
                    }
                    guard Set(parameters).count == parameters.count else {
                        throw RuntimeError(
                            message: "Handler '\(handlerName)' has duplicate parameters."
                        )
                    }
                    handlers[handlerName] = RuntimeFunction(
                        name: "\(name).\(handlerName)",
                        parameters: parameters,
                        body: handlerBody,
                        namespace: nil
                    )
                }
                states[name] = handlers
            default:
                break
            }
        }
    }

    private mutating func executeTopLevel(_ instructions: [Instruction]) throws {
        let executable = instructions.filter { instruction in
            switch instruction {
            case .function, .module, .stateDeclaration:
                false
            default:
                true
            }
        }
        let signal = try execute(executable)
        guard case .complete = signal else {
            throw RuntimeError(message: "Control flow cannot return or transition at program scope.")
        }
    }

    private mutating func runInitialState() throws {
        guard let handlers = states["default"] else {
            throw RuntimeError(message: "The JSON IR does not declare a 'default' state.")
        }
        currentState = "default"
        var signal = try invoke(handler: handlers["stateEntry"], named: "default.stateEntry")
        if isFinishedHandler(signal) {
            signal = .complete
        }

        while case let .transitioned(nextState) = signal {
            guard let nextHandlers = states[nextState] else {
                throw RuntimeError(message: "Transition targets undeclared state '\(nextState)'.")
            }
            if let exitHandler = states[currentState ?? ""]?["stateExit"] {
                let exitSignal = try invoke(handler: exitHandler, named: exitHandler.name)
                guard isFinishedHandler(exitSignal) else {
                    throw RuntimeError(message: "stateExit() cannot return or transition.")
                }
            }
            currentState = nextState
            signal = try invoke(
                handler: nextHandlers["stateEntry"],
                named: "\(nextState).stateEntry"
            )
            if isFinishedHandler(signal) {
                signal = .complete
            }
        }
        guard isFinishedHandler(signal) else {
            throw RuntimeError(message: "stateEntry() cannot return a value.")
        }
    }

    private func isFinishedHandler(_ signal: ExecutionSignal) -> Bool {
        switch signal {
        case .complete, .returned(.none):
            true
        case .returned, .transitioned:
            false
        }
    }

    private mutating func invoke(
        handler: RuntimeFunction?,
        named name: String
    ) throws -> ExecutionSignal {
        guard let handler else { return .complete }
        return try invoke(handler, arguments: [], callName: name)
    }

    private mutating func invoke(
        _ function: RuntimeFunction,
        arguments: [RuntimeValue],
        callName: String
    ) throws -> ExecutionSignal {
        guard callDepth < callDepthLimit else {
            throw RuntimeError(message: "Program exceeded the \(callDepthLimit)-call recursion limit.")
        }
        guard arguments.count == function.parameters.count else {
            throw RuntimeError(
                message: "Function '\(callName)' expects \(function.parameters.count) argument(s), got \(arguments.count)."
            )
        }
        scopes.append(Dictionary(
            uniqueKeysWithValues: zip(function.parameters, arguments).map { name, value in
                (name, RuntimeBinding(value: value, isMutableReference: false))
            }
        ))
        callDepth += 1
        let previousNamespace = currentNamespace
        currentNamespace = function.namespace
        defer {
            currentNamespace = previousNamespace
            scopes.removeLast()
            callDepth -= 1
        }

        switch try execute(function.body) {
        case .complete:
            return .complete
        case let .returned(value):
            return .returned(value)
        case let .transitioned(state):
            return .transitioned(state)
        }
    }

    private mutating func execute(_ instructions: [Instruction]) throws -> ExecutionSignal {
        for instruction in instructions {
            executedInstructions += 1
            guard executedInstructions <= instructionLimit else {
                throw RuntimeError(
                    message: "Program exceeded the \(instructionLimit)-instruction execution limit."
                )
            }

            switch instruction {
            case let .pushNumber(value):
                stack.append(.number(value))
            case let .pushBoolean(value):
                stack.append(.boolean(value))
            case let .pushTrilean(value):
                stack.append(.trilean(value))
            case let .pushString(value):
                stack.append(.string(value))
            case .pushNone:
                stack.append(.none)
            case let .load(name):
                stack.append(try load(name))
            case let .store(name):
                try store(name, value: pop(), isMutableReference: false)
            case let .storeMutable(name):
                try store(name, value: pop(), isMutableReference: true)
            case let .assign(name):
                let value = try pop()
                guard let binding = binding(named: name) else {
                    throw RuntimeError(message: "Unknown value '\(name)'.")
                }
                guard binding.isMutableReference else {
                    throw RuntimeError(
                        message: "Cannot mutate through immutable value '\(name)'."
                    )
                }
                binding.reference.value = value.resolved
            case .negate:
                let operand = try pop().resolved
                guard case let .number(value) = operand else {
                    throw typeError("Unary '-' requires a number, got \(operand.typeName).")
                }
                stack.append(.number(-value))
            case .not:
                let operand = try pop().resolved
                switch operand {
                case let .boolean(value):
                    stack.append(.boolean(!value))
                case let .trilean(value):
                    stack.append(.trilean(value.negated()))
                default:
                    throw typeError("Operator '!' requires Bool or Trilean, got \(operand.typeName).")
                }
            case .add, .subtract, .multiply, .divide,
                 .equal, .notEqual, .lessThan, .lessThanOrEqual,
                 .greaterThan, .greaterThanOrEqual, .and, .or:
                let right = try pop()
                let left = try pop()
                stack.append(try evaluate(instruction, left: left, right: right))
            case let .call(name, argumentCount):
                guard stack.count >= argumentCount else {
                    throw RuntimeError(message: "Stack underflow while preparing call to '\(name)'.")
                }
                let startIndex = stack.count - argumentCount
                let arguments = Array(stack[startIndex...])
                stack.removeSubrange(startIndex...)
                if let arity = hostFunctions[name] {
                    guard arguments.count == arity else {
                        throw RuntimeError(
                            message: "Function '\(name)' expects \(arity) argument(s), got \(arguments.count)."
                        )
                    }
                    hostCalls.append(HostCall(name: name, arguments: arguments.map(\.hostValue)))
                    stack.append(.none)
                    continue
                }
                let function = try resolveFunction(named: name)
                switch try invoke(function, arguments: arguments, callName: name) {
                case .complete:
                    stack.append(.none)
                case let .returned(value):
                    stack.append(value)
                case let .transitioned(state):
                    return .transitioned(state)
                }
            case .print:
                output.append(try pop().displayValue)
            case .discard:
                _ = try pop()
            case let .conditional(condition, then, otherwise):
                if try conditionValue(condition) {
                    let signal = try executeInScope(then)
                    if case .complete = signal { break }
                    return signal
                } else {
                    let signal = try executeInScope(otherwise)
                    if case .complete = signal { break }
                    return signal
                }
            case let .loop(condition, body):
                while try conditionValue(condition) {
                    let signal = try executeInScope(body)
                    if case .complete = signal { continue }
                    return signal
                }
            case let .match(expression, cases):
                let subject = try evaluate(expression)
                if let selected = cases.first(where: { matches(subject, pattern: $0.0) }) {
                    let signal = try executeInScope(selected.1)
                    if case .complete = signal { break }
                    return signal
                }
            case let .attempt(body, errorName, handler):
                do {
                    let signal = try executeInScope(body)
                    if case .complete = signal { break }
                    return signal
                } catch let runtimeError as RuntimeError {
                    let signal = try executeInScope(
                        handler,
                        binding: (errorName, .string(runtimeError.message))
                    )
                    if case .complete = signal { break }
                    return signal
                }
            case .throwError:
                let value = try pop().resolved
                throw RuntimeError(message: value.displayValue)
            case let .return(hasValue):
                return .returned(hasValue ? try pop() : .none)
            case .function, .module, .stateDeclaration:
                break
            case let .transition(to):
                return .transitioned(to)
            }
        }
        return .complete
    }

    private mutating func executeInScope(
        _ instructions: [Instruction],
        binding: (String, RuntimeValue)? = nil
    ) throws -> ExecutionSignal {
        let stackDepth = stack.count
        scopes.append([:])
        do {
            if let binding {
                try store(binding.0, value: binding.1, isMutableReference: false)
            }
            let signal = try execute(instructions)
            scopes.removeLast()
            return signal
        } catch {
            if stack.count > stackDepth {
                stack.removeLast(stack.count - stackDepth)
            }
            scopes.removeLast()
            throw error
        }
    }

    private mutating func evaluate(_ instructions: [Instruction]) throws -> RuntimeValue {
        let originalStackDepth = stack.count
        let signal: ExecutionSignal
        do {
            signal = try execute(instructions)
        } catch {
            if stack.count > originalStackDepth {
                stack.removeLast(stack.count - originalStackDepth)
            }
            throw error
        }
        guard case .complete = signal else {
            throw RuntimeError(message: "Control flow is not allowed inside an expression.")
        }
        guard stack.count == originalStackDepth + 1 else {
            throw RuntimeError(message: "Expression did not produce exactly one value.")
        }
        return try pop()
    }

    private mutating func conditionValue(_ instructions: [Instruction]) throws -> Bool {
        let value = try evaluate(instructions).resolved
        switch value {
        case let .boolean(boolean):
            return boolean
        case let .trilean(trilean):
            return trilean.booleanValue
        default:
            throw typeError(
                "A condition must be Bool or Trilean, got \(value.typeName)."
            )
        }
    }

    private mutating func load(_ name: String) throws -> RuntimeValue {
        guard let binding = binding(named: name) else {
            throw RuntimeError(message: "Unknown value '\(name)'.")
        }
        return binding.value
    }

    private func binding(named name: String) -> RuntimeBinding? {
        for scope in scopes.reversed() {
            if let binding = scope[name] { return binding }
        }
        return globals[name]
    }

    private mutating func store(
        _ name: String,
        value: RuntimeValue,
        isMutableReference: Bool
    ) throws {
        if scopes.isEmpty {
            guard globals[name] == nil else {
                throw RuntimeError(message: "Value '\(name)' is already declared.")
            }
            globals[name] = RuntimeBinding(
                value: value,
                isMutableReference: isMutableReference
            )
            return
        }
        guard scopes[scopes.count - 1][name] == nil else {
            throw RuntimeError(message: "Value '\(name)' is already declared in this scope.")
        }
        scopes[scopes.count - 1][name] = RuntimeBinding(
            value: value,
            isMutableReference: isMutableReference
        )
    }

    private func resolveFunction(named name: String) throws -> RuntimeFunction {
        if let function = functions[name] { return function }
        if let currentNamespace, let function = functions["\(currentNamespace).\(name)"] {
            return function
        }
        if let currentState, let handler = states[currentState]?[name] {
            return handler
        }
        throw RuntimeError(message: "Unknown function '\(name)'.")
    }

    private mutating func evaluate(
        _ operation: Instruction,
        left: RuntimeValue,
        right: RuntimeValue
    ) throws -> RuntimeValue {
        let left = left.resolved
        let right = right.resolved
        switch operation {
        case .add:
            if case let (.number(lhs), .number(rhs)) = (left, right) {
                return .number(lhs + rhs)
            }
            if case let (.string(lhs), .string(rhs)) = (left, right) {
                return .string(lhs + rhs)
            }
            throw typeError("'+' requires two numbers or two strings.")
        case .subtract:
            return .number(try number(left, operator: "-") - number(right, operator: "-"))
        case .multiply:
            return .number(try number(left, operator: "*") * number(right, operator: "*"))
        case .divide:
            let divisor = try number(right, operator: "/")
            guard divisor != 0 else { throw RuntimeError(message: "Division by zero.") }
            return .number(try number(left, operator: "/") / divisor)
        case .equal, .notEqual:
            if case .none = left { return .trilean(.unknown) }
            if case .none = right { return .trilean(.unknown) }
            let equal = valuesEqual(left, right)
            return .boolean(operation == .equal ? equal : !equal)
        case .lessThan, .lessThanOrEqual, .greaterThan, .greaterThanOrEqual:
            if case .none = left { return .trilean(.unknown) }
            if case .none = right { return .trilean(.unknown) }
            let lhs = try number(left, operator: "comparison")
            let rhs = try number(right, operator: "comparison")
            return switch operation {
            case .lessThan: .boolean(lhs < rhs)
            case .lessThanOrEqual: .boolean(lhs <= rhs)
            case .greaterThan: .boolean(lhs > rhs)
            case .greaterThanOrEqual: .boolean(lhs >= rhs)
            default: throw RuntimeError(message: "Invalid comparison instruction.")
            }
        case .and, .or:
            return switch (left, right) {
            case let (.boolean(lhs), .boolean(rhs)):
                .boolean(operation == .and ? lhs && rhs : lhs || rhs)
            case let (.trilean(lhs), .trilean(rhs)):
                .trilean(operation == .and
                    ? lhs.conjunction(with: rhs)
                    : lhs.disjunction(with: rhs))
            default:
                throw typeError("Logical operators require two Bool values or two Trilean values.")
            }
        default:
            throw RuntimeError(message: "Invalid binary instruction.")
        }
    }

    private func number(_ value: RuntimeValue, operator name: String) throws -> Double {
        guard case let .number(number) = value.resolved else {
            throw typeError("Operator '\(name)' requires numbers, got \(value.typeName).")
        }
        return number
    }

    private func truthValue(_ value: RuntimeValue) throws -> Trilean {
        switch value.resolved {
        case let .boolean(value): value ? .trueValue : .falseValue
        case let .trilean(value): value
        default: throw typeError("Operator '!' requires Bool or Trilean, got \(value.typeName).")
        }
    }

    private func valuesEqual(_ lhs: RuntimeValue, _ rhs: RuntimeValue) -> Bool {
        switch (lhs.resolved, rhs.resolved) {
        case let (.number(left), .number(right)): left == right
        case let (.boolean(left), .boolean(right)): left == right
        case let (.trilean(left), .trilean(right)): left == right
        case let (.string(left), .string(right)): left == right
        case (.none, .none): true
        default: false
        }
    }

    private func matches(_ value: RuntimeValue, pattern: MatchPattern) -> Bool {
        switch (value.resolved, pattern) {
        case (_, .wildcard): true
        case let (.boolean(value), .boolean(pattern)): value == pattern
        case let (.trilean(value), .trilean(pattern)): value == pattern
        case let (.number(value), .number(pattern)): value == pattern
        case let (.string(value), .string(pattern)): value == pattern
        case (.none, .none): true
        default: false
        }
    }

    private mutating func pop() throws -> RuntimeValue {
        guard let value = stack.popLast() else {
            throw RuntimeError(message: "Stack underflow.")
        }
        return value
    }

    private func typeError(_ message: String) -> RuntimeError {
        RuntimeError(message: message)
    }
}
