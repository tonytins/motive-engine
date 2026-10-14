import Foundation

/// A Robusta instruction encoded as a variable-length JSON array.
public enum Instruction: Sendable, Equatable {
    case pushNumber(Double)
    case pushBoolean(Bool)
    case pushString(String)
    case pushNone
    case load(String)
    case store(String)
    case storeMutable(String)
    case add
    case subtract
    case multiply
    case divide
    case print
    case function(name: String, parameters: [String], body: [Instruction])
    case module(name: String, body: [Instruction])
    case state(name: String, body: [Instruction])
    case transition(to: String)
}

extension Instruction: Codable {
    private enum Opcode: String {
        case pushNumber = "push_num"
        case pushBoolean = "push_bool"
        case pushString = "push_string"
        case pushNone = "push_none"
        case load
        case store
        case storeMutable = "store_mut"
        case add
        case subtract = "sub"
        case multiply = "mul"
        case divide = "div"
        case print
        case function = "func"
        case module = "mod"
        case state
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
        case .add:
            try container.encode(Opcode.add.rawValue)
        case .subtract:
            try container.encode(Opcode.subtract.rawValue)
        case .multiply:
            try container.encode(Opcode.multiply.rawValue)
        case .divide:
            try container.encode(Opcode.divide.rawValue)
        case .print:
            try container.encode(Opcode.print.rawValue)
        case let .function(name, parameters, body):
            try container.encode(Opcode.function.rawValue)
            try container.encode(name)
            try container.encode(parameters)
            try container.encode(body)
        case let .module(name, body):
            try container.encode(Opcode.module.rawValue)
            try container.encode(name)
            try container.encode(body)
        case let .state(name, body):
            try container.encode(Opcode.state.rawValue)
            try container.encode(name)
            try container.encode(body)
        case let .transition(to):
            try container.encode(Opcode.state.rawValue)
            try container.encode(to)
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
        case .add:
            self = .add
        case .subtract:
            self = .subtract
        case .multiply:
            self = .multiply
        case .divide:
            self = .divide
        case .print:
            self = .print
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
        case .state:
            let name = try container.decode(String.self)
            self = container.isAtEnd
                ? .transition(to: name)
                : .state(name: name, body: try container.decode([Instruction].self))
        }

        guard container.isAtEnd else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected extra values in Robusta instruction '\(rawOpcode)'."
            )
        }
    }
}
