import Foundation
import Testing
@testable import MotiveEngine

@Suite("Robusta pipeline")
struct PipelineTests {
    @Test("source is parsed by the injected frontend before lowering to JSON IR")
    func compilesSourceThroughFrontend() throws {
        let frontend = FixtureFrontend(statements: [
            .value(
                name: "x",
                isMutable: false,
                expression: .binary(.number(2), .add, .number(3))
            ),
            .print(.variable("x"))
        ])

        let ir = try RobustaCompiler.compile("fixture source", using: frontend)
        let expectedIR = Data(
            """
            [
              ["push_num", 2],
              ["push_num", 3],
              ["add"],
              ["store", "x"],
              ["load", "x"],
              ["print"]
            ]
            """.utf8
        )
        let actualJSON = try JSONSerialization.jsonObject(with: ir) as? NSArray
        let expectedJSON = try JSONSerialization.jsonObject(with: expectedIR) as? NSArray

        #expect(actualJSON?.isEqual(expectedJSON) == true)
        #expect(try RobustaCompiler.decode(ir: ir) == [
            .pushNumber(2),
            .pushNumber(3),
            .add,
            .store("x"),
            .load("x"),
            .print
        ])
    }

    @Test("mutable values and structural blocks survive an IR round trip")
    func roundTripsMutableAndNestedInstructions() throws {
        let instructions: [Instruction] = [
            .storeMutable("counter"),
            .module(
                name: "mathUtils",
                body: [
                    .function(
                        name: "add",
                        parameters: ["a", "b"],
                        body: [.load("a"), .load("b"), .add]
                    )
                ]
            ),
            .state(name: "default", body: [.transition(to: "active")]),
            .transition(to: "default")
        ]
        let ir = try JSONEncoder().encode(instructions)

        #expect(try RobustaCompiler.decode(ir: ir) == instructions)
    }

    @Test("unknown instructions fail to decode")
    func rejectsUnknownInstructions() {
        let ir = Data(#"[["run", "code"]]"#.utf8)

        #expect(throws: DecodingError.self) {
            try RobustaCompiler.decode(ir: ir)
        }
    }

    @Test("extra instruction operands fail to decode")
    func rejectsUnexpectedOperands() {
        let ir = Data(#"[["add", 2]]"#.utf8)

        #expect(throws: DecodingError.self) {
            try RobustaCompiler.decode(ir: ir)
        }
    }
}

private struct FixtureFrontend: Frontend {
    let statements: [Statement]

    func parse(_ source: String) throws -> [Statement] {
        statements
    }
}
