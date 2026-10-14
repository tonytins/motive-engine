/// An expression in the Robusta abstract syntax tree.
public indirect enum Expression: Sendable, Equatable {
    case number(Double)
    case boolean(Bool)
    case string(String)
    case none
    case variable(String)
    case binary(Expression, BinaryOperator, Expression)
}

/// A binary operator supported by Robusta expressions.
public enum BinaryOperator: String, Sendable, Equatable {
    case add
    case subtract
    case multiply
    case divide
}

/// A top-level declaration or executable statement in a Robusta program.
public indirect enum Statement: Sendable, Equatable {
    case value(name: String, isMutable: Bool, expression: Expression)
    case print(Expression)
    case function(name: String, parameters: [String], body: [Statement])
    case module(name: String, body: [Statement])
    case state(name: String, body: [Statement])
    case transition(to: String)
}
