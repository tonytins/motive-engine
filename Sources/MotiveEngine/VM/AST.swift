/// A three-valued truth value used by comparisons and logical expressions.
public enum Trilean: Sendable, Equatable {
    case trueValue
    case falseValue
    case unknown

    public var booleanValue: Bool {
        self == .trueValue
    }

    public func negated() -> Trilean {
        switch self {
        case .trueValue: .falseValue
        case .falseValue: .trueValue
        case .unknown: .unknown
        }
    }

    public func conjunction(with other: Trilean) -> Trilean {
        if self == .falseValue || other == .falseValue { return .falseValue }
        if self == .unknown || other == .unknown { return .unknown }
        return .trueValue
    }

    public func disjunction(with other: Trilean) -> Trilean {
        if self == .trueValue || other == .trueValue { return .trueValue }
        if self == .unknown || other == .unknown { return .unknown }
        return .falseValue
    }
}

/// An expression in the Robusta abstract syntax tree.
public indirect enum Expression: Sendable, Equatable {
    case number(Double)
    case boolean(Bool)
    case trilean(Trilean)
    case string(String)
    case none
    case variable(String)
    case member(Expression, String)
    case call(Expression, [Expression])
    case unary(UnaryOperator, Expression)
    case binary(Expression, BinaryOperator, Expression)
}

/// A unary operator supported by Robusta expressions.
public enum UnaryOperator: Sendable, Equatable {
    case not
    case negate
}

/// A binary operator supported by Robusta expressions.
public enum BinaryOperator: String, Sendable, Equatable, CaseIterable {
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

    public static var sub: Self { .subtract }
    public static var mul: Self { .multiply }
    public static var div: Self { .divide }
    public static var eq: Self { .equal }
    public static var neq: Self { .notEqual }
    public static var lt: Self { .lessThan }
    public static var lte: Self { .lessThanOrEqual }
    public static var gt: Self { .greaterThan }
    public static var gte: Self { .greaterThanOrEqual }
}

/// A pattern that can be matched against a Robusta value.
public enum MatchPattern: Sendable, Equatable {
    case boolean(Bool)
    case trilean(Trilean)
    case number(Double)
    case string(String)
    case none
    case wildcard
}

/// A top-level declaration or executable statement in a Robusta program.
public indirect enum Statement: Sendable, Equatable {
    case value(name: String, isMutable: Bool, expression: Expression)
    case assign(name: String, expression: Expression)
    case expression(Expression)
    case print(Expression)
    case function(name: String, parameters: [String], body: [Statement])
    case module(name: String, body: [Statement])
    case state(name: String, body: [Statement])
    case transition(to: String)
    case conditional(condition: Expression, then: [Statement], otherwise: [Statement])
    case loop(condition: Expression, body: [Statement])
    case match(expression: Expression, cases: [(MatchPattern, [Statement])])
    case attempt(body: [Statement], errorName: String, handler: [Statement])
    case throwValue(Expression)
    case returnValue(Expression?)

    public static func == (lhs: Statement, rhs: Statement) -> Bool {
        switch (lhs, rhs) {
        case let (.value(ln, lm, le), .value(rn, rm, re)):
            ln == rn && lm == rm && le == re
        case let (.assign(ln, le), .assign(rn, re)):
            ln == rn && le == re
        case let (.expression(left), .expression(right)):
            left == right
        case let (.print(left), .print(right)):
            left == right
        case let (.function(ln, lp, lb), .function(rn, rp, rb)):
            ln == rn && lp == rp && lb == rb
        case let (.module(ln, lb), .module(rn, rb)):
            ln == rn && lb == rb
        case let (.state(ln, lb), .state(rn, rb)):
            ln == rn && lb == rb
        case let (.transition(left), .transition(right)):
            left == right
        case let (.conditional(lc, lt, lo), .conditional(rc, rt, ro)):
            lc == rc && lt == rt && lo == ro
        case let (.loop(lc, lb), .loop(rc, rb)):
            lc == rc && lb == rb
        case let (.match(le, lc), .match(re, rc)):
            le == re && lc.elementsEqual(rc, by: ==)
        case let (.attempt(lb, ln, lh), .attempt(rb, rn, rh)):
            lb == rb && ln == rn && lh == rh
        case let (.throwValue(left), .throwValue(right)):
            left == right
        case let (.returnValue(left), .returnValue(right)):
            left == right
        default:
            false
        }
    }
}
