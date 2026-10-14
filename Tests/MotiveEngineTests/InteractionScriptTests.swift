import Foundation
import MotiveEngine
import Testing

@Suite("Interaction scripts")
struct InteractionScriptTests {
    @Test func scriptsReadDeclaredInputsAndReportEffects() throws {
        let script = try InteractionScript(source: """
        state default
            func stateEntry()
                if sim.hunger < 30
                    effect.fulfill("hunger", 3)
                else
                    effect.fulfill("hunger", 1)
                end
                effect.fulfill("fun", 0 - 0.5)
                print item.id + " " + item.definition + " " + interaction.id
                print interaction.name + " " + sim.id + " " + sim.posture
                print interaction.duration
            end
        end
        """)

        let hungry = try InteractionScriptSystem.evaluate(script, input: makeInput(hunger: 20))
        let fed = try InteractionScriptSystem.evaluate(script, input: makeInput(hunger: 80))

        #expect(hungry.motiveEffects == [
            MotiveSignal(motiveType: .hunger, strengthPerSecond: 3),
            MotiveSignal(motiveType: .fun, strengthPerSecond: -0.5),
        ])
        #expect(fed.motiveEffects.first == MotiveSignal(motiveType: .hunger, strengthPerSecond: 1))
        #expect(hungry.output == ["fridge-1 fridge eat", "Eat bob standing", "20"])
    }

    @Test func everyMotiveIsAvailableAsAnInput() throws {
        let reads = MotiveType.allCases.map { "print sim.\($0.rawValue)" }.joined(separator: "\n")
        let script = try InteractionScript(source: """
        \(reads)
        state default
            func stateEntry()
            end
        end
        """)

        let result = try InteractionScriptSystem.evaluate(script, input: makeInput(hunger: 20))

        #expect(result.output == ["20", "50", "50", "50", "50", "50"])
        #expect(result.motiveEffects.isEmpty)
    }

    @Test func evaluationIsRepeatableAndDoesNotChangeInput() throws {
        let script = try InteractionScript(source: """
        state default
            func stateEntry()
                effect.fulfill("energy", 100 - sim.energy)
            end
        end
        """)
        let input = try makeInput(hunger: 50)

        let first = try InteractionScriptSystem.evaluate(script, input: input)
        let second = try InteractionScriptSystem.evaluate(script, input: input)

        #expect(first == second)
        #expect(first.motiveEffects == [MotiveSignal(motiveType: .energy, strengthPerSecond: 50)])
        #expect(input.sim.motives.level(for: .energy) == 50)
    }

    @Test func scriptsCannotRedeclareInputsOrHostFunctions() throws {
        #expect(throws: InteractionScriptError.reservedModule("effect")) {
            try InteractionScript(source: """
            mod effect
                func fulfill(motive, strength)
                end
            end
            state default
                func stateEntry()
                end
            end
            """)
        }

        // Inputs are dotted names, which the language cannot assign to.
        #expect(throws: (any Error).self) {
            try InteractionScript(source: """
            state default
                func stateEntry()
                    sim.hunger = 100
                end
            end
            """)
        }
    }

    @Test func invalidEffectsAreReportedAsTypedErrors() throws {
        let cases: [(String, InteractionScriptError)] = [
            ("effect.fulfill(\"thirst\", 1)", .unknownMotive("thirst")),
            ("effect.fulfill(1, \"hunger\")", .invalidEffectArguments),
            ("effect.fulfill(\"fun\", None)", .invalidEffectArguments),
            ("""
            mut val big = 10
            while big * 10 > big
                big = big * 10
            end
            effect.fulfill("fun", big)
            """, .nonFiniteEffect(.fun)),
        ]
        for (call, expectedError) in cases {
            let script = try InteractionScript(source: """
            state default
                func stateEntry()
                    \(call)
                end
            end
            """)
            #expect(throws: expectedError) {
                try InteractionScriptSystem.evaluate(script, input: makeInput(hunger: 50))
            }
        }
    }

    @Test func runtimeFailuresPropagateWithoutPartialEffects() throws {
        let wrongArity = try InteractionScript(source: """
        state default
            func stateEntry()
                effect.fulfill("fun")
            end
        end
        """)
        let thrown = try InteractionScript(source: """
        state default
            func stateEntry()
                effect.fulfill("fun", 1)
                throw "broken"
            end
        end
        """)
        let endless = try InteractionScript(source: """
        state default
            func stateEntry()
                while true
                end
            end
        end
        """)

        for script in [wrongArity, thrown, endless] {
            #expect(throws: RuntimeError.self) {
                try InteractionScriptSystem.evaluate(script, input: makeInput(hunger: 50))
            }
        }
    }

    @Test func scriptCanRecoverFromItsOwnErrors() throws {
        let script = try InteractionScript(source: """
        state default
            func stateEntry()
                try
                    throw "no snacks"
                catch problem
                    print problem
                    effect.fulfill("hunger", 0.5)
                end
            end
        end
        """)

        let result = try InteractionScriptSystem.evaluate(script, input: makeInput(hunger: 50))

        #expect(result.output == ["no snacks"])
        #expect(result.motiveEffects == [MotiveSignal(motiveType: .hunger, strengthPerSecond: 0.5)])
    }

    @Test func scriptedEffectsDriveTheExistingActionModel() throws {
        let script = try InteractionScript(source: """
        state default
            func stateEntry()
                effect.fulfill("hunger", 2)
            end
        end
        """)
        let input = try makeInput(hunger: 40)
        let effects = try InteractionScriptSystem.evaluate(script, input: input).motiveEffects

        let fed = try MotiveSystem.fulfill(input.sim.motives, with: effects, overSeconds: 5)

        #expect(fed.level(for: .hunger) == 50)
    }

    // MARK: - Fixtures

    private func makeInput(hunger: Double) throws -> InteractionScriptInput {
        let definitionID = try #require(ItemDefinitionID("fridge"))
        let definition = try ItemDefinition(
            id: definitionID,
            identity: ItemIdentity(name: "Fridge", itemTypes: .appliance),
            signals: [],
            interactions: [
                InteractionDefinition(
                    id: #require(InteractionDefinitionID("eat")),
                    name: "Eat",
                    advertisedBenefits: [MotiveBenefit(motiveType: .hunger, expectedStrengthPerSecond: 2)],
                    motiveEffects: [],
                    durationSeconds: 20
                ),
            ]
        )
        let catalog = try ItemDefinitionCatalog(definitions: [definition])
        let item = PlacedItem(
            id: try #require(ItemInstanceID("fridge-1")),
            definitionID: definitionID,
            position: GridPosition(x: 0, y: 0)
        )
        var levels = Dictionary(uniqueKeysWithValues: MotiveType.allCases.map { ($0, 50.0) })
        levels[.hunger] = hunger
        let sim = SimStateData(
            id: try #require(SimID("bob")),
            motives: try MotiveLevels(levels: levels),
            posture: .standing
        )
        return InteractionScriptInput(
            sim: sim,
            offer: try #require(catalog.interactionOffers(for: item).first)
        )
    }
}
