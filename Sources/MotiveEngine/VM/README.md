# Robusta VM

Robusta is the VM and scripting-language design for item logic. Its pipeline
separates source parsing, the abstract syntax tree (AST), JSON intermediate
representation (IR), and execution.

The frontend is injected through `Frontend`, so source parsing can be replaced
without coupling the compiler to a particular parser. The compiler currently
lowers AST statements and expressions into flat, stack-oriented instructions.
Function, module, and state bodies remain nested structural blocks in the JSON.

```swift
let statements: [Statement] = [
    .value(
        name: "x",
        isMutable: false,
        expression: .binary(.number(2), .add, .number(3))
    ),
    .print(.variable("x"))
]
```

This lowers to the following JSON IR:

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

Execution and the remaining language semantics are not implemented yet.
