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
            lower(expression) + [isMutable ? .storeMutable(name) : .store(name)]
        case let .print(expression):
            lower(expression) + [.print]
        case let .function(name, parameters, body):
            [.function(name: name, parameters: parameters, body: lower(statements: body))]
        case let .module(name, body):
            [.module(name: name, body: lower(statements: body))]
        case let .state(name, body):
            [.state(name: name, body: lower(statements: body))]
        case let .transition(to):
            [.transition(to: to)]
        }
    }

    private static func lower(_ expression: Expression) -> [Instruction] {
        switch expression {
        case let .number(value):
            return [.pushNumber(value)]
        case let .boolean(value):
            return [.pushBoolean(value)]
        case let .string(value):
            return [.pushString(value)]
        case .none:
            return [.pushNone]
        case let .variable(name):
            return [.load(name)]
        case let .binary(left, operation, right):
            let opcode: Instruction
            switch operation {
            case .add: opcode = .add
            case .subtract: opcode = .subtract
            case .multiply: opcode = .multiply
            case .divide: opcode = .divide
            }
            return lower(left) + lower(right) + [opcode]
        }
    }
}
