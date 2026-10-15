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

    @Test("source, AST, and JSON IR run entry points return the same output")
    func supportsAllPipelineRunEntryPoints() throws {
        let source = """
        state default
            func stateEntry()
                print "ready"
            end
        end
        """
        let frontend = RobustaFrontend()
        let statements = try frontend.parse(source)
        let ir = try RobustaCompiler.compile(source, using: frontend)

        #expect(try RobustaVM.run(source, using: frontend) == ["ready"])
        #expect(try RobustaVM.run(statements) == ["ready"])
        #expect(try RobustaVM.run(ir: ir) == ["ready"])
    }

    @Test("mutable values and structural blocks survive an IR round trip")
    func roundTripsMutableAndNestedInstructions() throws {
        let instructions: [Instruction] = [
            .storeMutable("counter"),
            .conditional(
                condition: [.pushBoolean(true)],
                then: [.print],
                otherwise: []
            ),
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
            .match(
                expression: [.load("counter")],
                cases: [(.number(1), [.print]), (.wildcard, [])]
            ),
            .attempt(
                body: [.pushString("failed"), .throwError],
                errorName: "problem",
                handler: [.print]
            ),
            .stateDeclaration(name: "default", body: [.transition(to: "active")]),
            .transition(to: "default")
        ]
        let ir = try JSONEncoder().encode(instructions)
        let expectedStructure = Data(
            """
            [
              ["store_mut", "counter"],
              ["if", [["push_bool", true]], ["then", [["print"]]], ["else", []]],
              ["mod", "mathUtils", [["func", "add", ["a", "b"], [["load", "a"], ["load", "b"], ["add"]]]]],
              ["match", [["load", "counter"]], [["case", ["number", 1], [["print"]]], ["_", []]]],
              ["try", [["push_string", "failed"], ["throw"]], ["catch", "problem", [["print"]]]],
              ["state_decl", "default", [["state", "active"]]],
              ["state", "default"]
            ]
            """.utf8
        )
        let actualJSON = try JSONSerialization.jsonObject(with: ir) as? NSArray
        let expectedJSON = try JSONSerialization.jsonObject(with: expectedStructure) as? NSArray

        #expect(actualJSON?.isEqual(expectedJSON) == true)
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

    @Test("production frontend runs globals, module functions, and default state entry")
    func runsCompleteSourcePipeline() throws {
        let source = """
        mod mathUtils
            func add(a, b)
                return a + b
            end
        end

        val greeting = "Robusta"
        val total = mathUtils.add(2, 3)

        state default
            func stateEntry()
                print greeting
                print total
            end
        end
        """

        #expect(try RobustaVM.run(source) == ["Robusta", "5"])
    }

    @Test("while loops mutate mut val and Unknown conditions behave as false")
    func runsMutableLoopsAndTrileanConditions() throws {
        let source = """
        mut val count = 0
        while count < 3
            print count
            count = count + 1
        end

        state default
            func stateEntry()
                if None == 1
                    print "unexpected"
                else
                    print "Unknown is false here"
                end
            end
        end
        """

        #expect(try RobustaVM.run(source) == ["0", "1", "2", "Unknown is false here"])
    }

    @Test("immutable aliases observe mutations made through a mutable reference")
    func aliasesShareTheReferencedValue() throws {
        let source = """
        mut val count = 1
        val alias = count
        count = 2

        state default
            func stateEntry()
                print alias
            end
        end
        """

        #expect(try RobustaVM.run(source) == ["2"])
    }

    @Test("function arguments share references with mutable aliases")
    func functionArgumentsPreserveReferences() throws {
        let source = """
        func update(value)
            mut val alias = value
            alias = 9
        end

        mut val count = 1
        update(count)

        state default
            func stateEntry()
                print count
            end
        end
        """

        #expect(try RobustaVM.run(source) == ["9"])
    }

    @Test("Bool and Trilean operators preserve their operand type")
    func keepsBooleanAndTrileanLogicSeparate() throws {
        let source = """
        state default
            func stateEntry()
                print !false
                print !False
                print True && Unknown
                print False || True
                print None == None
                print None < 1
                print False && Unknown
                print True || Unknown
            end
        end
        """

        #expect(try RobustaVM.run(source) == [
            "true",
            "true",
            "unknown",
            "true",
            "unknown",
            "unknown",
            "false",
            "true"
        ])
    }

    @Test("Bool and Trilean operands cannot be mixed")
    func rejectsMixedLogicalTypes() {
        let source = """
        state default
            func stateEntry()
                print true && false && True
            end
        end
        """

        #expect(throws: RuntimeError.self) {
            try RobustaVM.run(source)
        }
    }

    @Test("legacy operator and state instruction names remain source-compatible")
    func preservesEarlierPublicNames() {
        #expect(BinaryOperator.sub == .subtract)
        #expect(
            Instruction.state(name: "default", body: [])
                == .stateDeclaration(name: "default", body: [])
        )
    }

    @Test("match wildcard and try catch execute their selected blocks")
    func runsMatchAndTryCatch() throws {
        let source = """
        state default
            func stateEntry()
                match 3
                    case 2
                        print "two"
                    case 3
                        print "three"
                    _
                        print "other"
                end

                try
                    print 2 + 1 / 0
                catch problem
                    print problem
                end

                try
                    throw "explicit error"
                catch problem
                    print problem
                end
            end
        end
        """

        #expect(try RobustaVM.run(source) == ["three", "Division by zero.", "explicit error"])
    }

    @Test("state transition invokes exit and entry handlers in order")
    func transitionsBetweenStates() throws {
        let source = """
        state default
            func stateEntry()
                print "default"
                state active
            end

            func stateExit()
                print "exit"
            end
        end

        state active
            func stateEntry()
                print "active"
            end
        end
        """

        #expect(try RobustaVM.run(source) == ["default", "exit", "active"])
    }

    @Test("the program entry state and immutable values are validated")
    func rejectsInvalidProgramAndMutation() {
        #expect(throws: ProgramError.self) {
            try RobustaVM.run("print 1")
        }

        let source = """
        val count = 1
        count = 2
        state default
            func stateEntry()
            end
        end
        """
        #expect(throws: RuntimeError.self) {
            try RobustaVM.run(source)
        }
    }

    @Test("unknown transition targets are rejected before execution")
    func rejectsUnknownStateTransition() {
        let source = """
        state default
            func stateEntry()
                state missing
            end
        end
        """

        #expect(throws: ProgramError.self) {
            try RobustaVM.run(source)
        }
    }

    @Test("unbounded recursion stops at the call-depth limit")
    func stopsUnboundedRecursionAtTheCallDepthLimit() throws {
        let source = """
        mod counter
            func down(depth)
                if depth == 0
                    return "bottom"
                end
                return counter.down(depth - 1)
            end
        end
        state default
            func stateEntry()
                print counter.down(depthToReach)
            end
        end
        """

        // Shallow recursion still works, so the limit is what stops deep recursion.
        #expect(try RobustaVM.run("val depthToReach = 200\n" + source) == ["bottom"])
        #expect(throws: RuntimeError(message: "Program exceeded the 256-call recursion limit.")) {
            try RobustaVM.run("val depthToReach = 10000\n" + source)
        }
    }
}

private struct FixtureFrontend: Frontend {
    let statements: [Statement]

    func parse(_ source: String) throws -> [Statement] {
        statements
    }
}
