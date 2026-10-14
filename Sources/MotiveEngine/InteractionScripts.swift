/// A compiled Robusta script that computes motive effects for an interaction.
///
/// The script is parsed and validated once when created. It reads declared
/// inputs and reports effects by calling `effect.fulfill(motive, strength)`.
/// It cannot read or change simulation state directly.
public struct InteractionScript: Equatable, Sendable {
    /// The module name reserved for host-provided effect functions.
    static let effectModuleName = "effect"
    static let fulfillFunctionName = "effect.fulfill"

    let instructions: [Instruction]

    /// Parses and validates a Robusta program for interaction evaluation.
    ///
    /// - Throws: Lexer, parser, or `ProgramError` values for invalid source,
    ///   or `InteractionScriptError.reservedModule` when the program declares
    ///   the host-owned `effect` module.
    public init(source: String, using frontend: any Frontend = RobustaFrontend()) throws {
        let instructions = try RobustaCompiler.validatedInstructions(source, using: frontend)
        for instruction in instructions {
            if case let .module(name, _) = instruction, name == Self.effectModuleName {
                throw InteractionScriptError.reservedModule(name)
            }
        }
        self.instructions = instructions
    }
}

/// The read-only values an interaction script can read.
///
/// Scripts read these as dotted names:
///
/// - `sim.id` and `sim.posture` (`"standing"` or `"sitting"`) are strings.
/// - `sim.hunger`, `sim.energy`, `sim.hygiene`, `sim.bladder`, `sim.social`,
///   and `sim.fun` are the Sim's motive levels.
/// - `item.id` and `item.definition` are the offer's instance and definition IDs.
/// - `interaction.id` and `interaction.name` are strings, and
///   `interaction.duration` is the duration in seconds.
public struct InteractionScriptInput: Sendable {
    /// The Sim the interaction is evaluated for.
    public let sim: SimStateData

    /// The interaction candidate being evaluated.
    public let offer: InteractionOffer

    /// Creates script input for one Sim and offer.
    public init(sim: SimStateData, offer: InteractionOffer) {
        self.sim = sim
        self.offer = offer
    }

    var hostValues: [String: HostValue] {
        var values: [String: HostValue] = [
            "sim.id": .string(sim.id.rawValue),
            "sim.posture": .string(sim.posture.rawValue),
            "item.id": .string(offer.itemInstanceID.rawValue),
            "item.definition": .string(offer.itemDefinitionID.rawValue),
            "interaction.id": .string(offer.interactionDefinitionID.rawValue),
            "interaction.name": .string(offer.name),
            "interaction.duration": .number(offer.durationSeconds),
        ]
        for motiveType in MotiveType.allCases {
            values["sim.\(motiveType.rawValue)"] = .number(sim.motives.level(for: motiveType))
        }
        return values
    }
}

/// The validated output of one interaction script run.
public struct InteractionScriptResult: Equatable, Sendable {
    /// Per-second motive effects in the order the script reported them.
    public let motiveEffects: [MotiveSignal]

    /// Lines written by `print`, for diagnostics.
    public let output: [String]
}

/// An invalid interaction script or script result.
public enum InteractionScriptError: Error, Equatable, Sendable {
    /// The script declares a module reserved for host functions.
    case reservedModule(String)

    /// `effect.fulfill` was not called with a string and a number.
    case invalidEffectArguments

    /// `effect.fulfill` named a motive the engine does not define.
    case unknownMotive(String)

    /// `effect.fulfill` reported a non-finite strength.
    case nonFiniteEffect(MotiveType)
}

/// Runs interaction scripts at the typed boundary between Robusta and the engine.
public enum InteractionScriptSystem {
    /// Runs a script against read-only input and validates its effects.
    ///
    /// The script cannot change simulation state. Its `effect.fulfill` calls
    /// are recorded and returned as motive signals; applying them is the
    /// caller's responsibility. The same script and input always produce the
    /// same result.
    ///
    /// - Throws: `RuntimeError` when the script fails, including the VM's
    ///   instruction limit, or `InteractionScriptError` for invalid effects.
    public static func evaluate(
        _ script: InteractionScript,
        input: InteractionScriptInput
    ) throws -> InteractionScriptResult {
        var interpreter = Interpreter(
            instructions: script.instructions,
            hostValues: input.hostValues,
            hostFunctions: [InteractionScript.fulfillFunctionName: 2]
        )
        let output = try interpreter.run()

        let effects = try interpreter.hostCalls.map { call in
            guard call.arguments.count == 2,
                  case let .string(motiveName) = call.arguments[0],
                  case let .number(strength) = call.arguments[1]
            else {
                throw InteractionScriptError.invalidEffectArguments
            }
            guard let motiveType = MotiveType(rawValue: motiveName) else {
                throw InteractionScriptError.unknownMotive(motiveName)
            }
            guard strength.isFinite else {
                throw InteractionScriptError.nonFiniteEffect(motiveType)
            }
            return MotiveSignal(motiveType: motiveType, strengthPerSecond: strength)
        }
        return InteractionScriptResult(motiveEffects: effects, output: output)
    }
}
