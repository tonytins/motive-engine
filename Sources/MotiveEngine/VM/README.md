# Robusta Language and Virtual Machine

Robusta is Motive Engine's render-independent scripting language for describing
item behavior. This document specifies the implemented language and its current
runtime boundary. It does not prescribe a redesign of the broader engine.

## Role in Motive Engine

Motive Engine is organized around independent systems for needs, buffs, and
aspirations. The simulation passes information downstream; it does not require
the scripting runtime to know about a renderer or a particular frontend.

Robusta follows that separation:

- A Robusta program can be parsed, compiled, and run without a `Sim`, `Item`,
  `MotiveSignal`, or UI instance.
- `print` produces output lines returned by the VM. Runtime and language errors
  are thrown to the caller.
- The language core has no built-in binding to Motive Engine's broadcasting,
  motive fulfillment, buffs, or item lifecycle. The engine reaches scripts only
  through the host boundary described below.

This keeps the VM independently testable while giving the engine one explicit,
typed adapter.

## Host Boundary

The interpreter accepts two optional host declarations, both owned by the
caller:

- **Host values** become immutable globals before top-level code runs. Dotted
  names such as `sim.hunger` are read with ordinary member syntax and cannot be
  assigned, because assignment targets must be plain identifiers.
- **Host functions** are declared by qualified name and arity. A call checks
  the argument count, records the call and its plain values in order, and
  returns `None`. The host interprets the recorded calls after the run. Scripts
  cannot declare functions with a reserved host name.

### Item interactions

`InteractionScript` compiles and validates a program once. It rejects a
program that declares the reserved `effect` module.
`InteractionScriptSystem.evaluate(_:input:)` runs it against an
`InteractionScriptInput` built from a `SimStateData` and an `InteractionOffer`.

| Input | Type |
| --- | --- |
| `sim.id`, `sim.posture` | string (`"standing"` or `"sitting"`) |
| `sim.hunger`, `sim.energy`, `sim.hygiene`, `sim.bladder`, `sim.social`, `sim.fun` | number, 0–100 |
| `item.id`, `item.definition` | string |
| `interaction.id`, `interaction.name` | string |
| `interaction.duration` | number, seconds |

The only output is `effect.fulfill(motive, strengthPerSecond)`. The engine
validates each call after the run and returns `MotiveSignal` values in call
order, along with any `print` output:

```robusta
state default
    func stateEntry()
        if sim.hunger < 30
            effect.fulfill("hunger", 3)
        else
            effect.fulfill("hunger", 1)
        end
    end
end
```

Wrong argument types, unknown motive names, and non-finite strengths are
reported as `InteractionScriptError` values. Script failures, including the
instruction limit, are thrown as `RuntimeError`, and no partial effects are
returned. Evaluation is deterministic and never changes simulation state;
applying the returned effects is the caller's responsibility.
`SimulationSession` does not run interaction scripts yet.

## Pipeline and API

Source flows through a replaceable frontend, a typed abstract syntax tree (AST),
JSON intermediate representation (IR), and the VM:

```text
source --RobustaFrontend--> AST --RobustaCompiler--> JSON IR --RobustaVM--> output
```

`Frontend` is a protocol, so callers can provide another parser without
changing the compiler or runtime. The package's `RobustaFrontend` is the
production parser.

```swift
let output = try RobustaVM.run(source)
let outputUsingCustomParser = try RobustaVM.run(source, using: frontend)
```

The runner validates program declarations and state transitions before lowering
to IR. `RobustaCompiler.compile(_:using:)` exposes the source-to-JSON stage.
AST-only and raw-IR run entry points are internal test seams; application code
should use the source runner.

The runtime enforces a 100,000-instruction execution limit per run. This also
bounds loops and repeated state transitions.

## Lexical Rules

- Identifiers begin with a letter or `_`, followed by letters, numbers, or `_`.
- Numbers are integers or decimal literals.
- Strings use double quotes. `\n`, `\t`, `\"`, and `\\` are supported escapes.
- `//`, `#`, and case-insensitive `REM` start line comments. `//` is the
  preferred spelling.
- Whitespace separates tokens. Newlines are not statement terminators; keyword
  structure and `end` delimit blocks.
- Keywords are case-sensitive except that `Unknown` and `unknown` are both
  accepted for the Trilean unknown value.

## Values and Bindings

The runtime values are numbers, strings, `Bool`, `Trilean`, and `None`. Values
are held through references by default.

```robusta
val greeting = "hello"
mut val counter = 0

counter = counter + 1
print greeting
```

- `val name = expression` creates an immutable reference. Rebinding or
  mutating the referenced value through that binding is rejected.
- `mut val name = expression` creates a mutable reference. Assignment mutates
  the referenced value in place, so aliases observe the updated value.
- Assignments use `name = expression` and require a `mut val` binding.
- Function parameters are immutable references.
- The current language has no collection/object constructors or property
  mutation syntax. Reference behavior applies to values and aliases available
  through the language and its future host bindings.

There is no null value. `None` represents an empty value:

```robusta
val absent = None
```

Comparisons involving `None` produce `Unknown`, including `None == None`.
`None` remains distinct from a runtime error; failures are thrown by the VM.
First-class `Result` values are not yet part of the source language.

## Bool and Trilean

`Bool` and `Trilean` are separate types:

| Source literal | Type |
| --- | --- |
| `true`, `false` | `Bool` |
| `True`, `False`, `Unknown` or `unknown` | `Trilean` |

The capitalized Boolean spellings are Trilean literals. This preserves
lowercase `true` and `false` as Bool while retaining the earlier `Unknown`
spelling; lowercase `unknown` is also accepted.

`!`, `&&`, and `||` preserve the operand type:

- Bool operators require Bool operands and produce Bool.
- Trilean operators require Trilean operands and produce Trilean.
- Mixing Bool and Trilean operands is a runtime type error.
- Trilean logic uses three-valued truth tables. For example,
  `True && Unknown` is `Unknown`, while `False && Unknown` is `False`.
- `if` and `while` accept either Bool or Trilean. `Unknown` behaves as false.

Comparisons between ordinary values produce Bool. A comparison involving
`None` produces Trilean `Unknown`.

## Expressions

Expressions include literals, variable references, module-qualified function
calls, unary operators, and binary operators.

Binary precedence, from lowest to highest:

1. `||`
2. `&&`
3. `==`, `!=`
4. `<`, `<=`, `>`, `>=`
5. `+`, `-`
6. `*`, `/`

Parentheses can group expressions. Arithmetic operates on numbers; `+` also
concatenates two strings. Relational comparisons currently operate on numbers.
Logical operands are evaluated eagerly from left to right.

## Declarations and Functions

Top-level declarations and executable statements are allowed. A `mod` defines
a namespace of functions; it is not a state and does not have an entry point.
Modules and functions close with `end`.

```robusta
mod mathUtils
    func add(a, b)
        return a + b
    end
end

val total = mathUtils.add(2, 3)
```

Functions may use `return expression` or bare `return`. Falling off the end of
a function returns `None`. Calls must match the declared parameter count.

## Control Flow and Errors

`if` supports an optional `else`; `while` repeats while its condition is true.
Both close with `end`.

```robusta
if count > 0
    print "ready"
else
    print "waiting"
end
```

`match` selects the first matching literal case. A final `_` arm is the
catch-all:

```robusta
match status
    case "ready"
        print "go"
    case None
        print "empty"
    _
        print "other"
end
```

`throw expression` raises a VM error. `try`/`catch` catches VM runtime errors
and thrown values and binds the error message to the identifier after `catch`:

```robusta
try
    throw "not ready"
catch problem
    print problem
end
```

Lexing, parsing, program validation, malformed IR, type errors, missing names,
invalid state transitions, and runtime failures are reported as errors; they
are never silently converted to successful output.

## State Machine

A program has one state machine. State declarations are top-level, state names
are unique, and a `default` state with a parameterless `stateEntry()` is
required. `stateExit()` is optional. Other functions declared inside a state
are reserved for state/event handlers.

```robusta
state default
    func stateEntry()
        print "starting"
        state active
    end

    func stateExit()
        print "leaving default"
    end
end

state active
    func stateEntry()
        print "active"
    end
end
```

The runner executes top-level code, invokes `default.stateEntry()`, and follows
state transitions. A transition invokes the current state's `stateExit()` when
present, then the destination state's `stateEntry()` when present. Transition
targets are validated before execution. External event dispatch is not part of
the current runner API.

## JSON Intermediate Representation

The IR is a JSON array of variable-length instruction arrays. Expressions
lower to a flat stack instruction sequence; nested JSON arrays are reserved
for structural blocks and function/module/state bodies.

For example:

```robusta
val x = 2 + 3
print x
```

lowers to:

```json
[
  ["push_num", 2],
  ["push_num", 3],
  ["add"],
  ["store", "x"],
  ["load", "x"],
  ["print"]
]
```

Literal and variable instructions include `push_num`, `push_bool`,
`push_trilean`, `push_string`, `push_none`, `load`, `store`, and `store_mut`.
Arithmetic and comparison instructions operate on stack values. Calls carry a
qualified name and argument count.

Blocks are encoded structurally. For example:

```json
["if",
  [["push_bool", true]],
  ["then", [["push_string", "yes"], ["print"]]],
  ["else", [["push_string", "no"], ["print"]]]
]
```

Match arms use `["case", pattern, body]` and `["_", body]`; error handling uses
`["try", body, ["catch", name, body]]`. The typed `Instruction` decoder
validates opcode names, operand types, operand counts, and nested block shapes
before execution.
