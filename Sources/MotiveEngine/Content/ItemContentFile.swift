import Foundation

/// The decoded `items.json` file of a content pack.
///
/// Motive values are per-second rates. An interaction's `script` names a
/// file in the pack's `scripts` folder without its `.rob` extension.
struct ItemContentFile: Decodable {
    struct ItemEntry: Decodable {
        let id: ItemDefinitionID
        let name: String
        let modifiers: [ItemModifier]
        let blocking: Bool?
        let capacity: Int?
        let signals: [String: Double]?
        let interactions: [InteractionEntry]?
    }

    struct InteractionEntry: Decodable {
        let id: InteractionDefinitionID
        let name: String
        let duration: Double
        let advertises: [String: Double]?
        let effects: [String: Double]?
        let posture: SimPosture?
        let script: String?
    }

    let items: [ItemEntry]

    /// Builds definitions, resolving each script name with `script(named:)`.
    ///
    /// Definition IDs are returned as written; the composer qualifies them.
    func definitions(
        script: (String) throws -> InteractionScript
    ) throws -> [ItemDefinition] {
        try items.map { item in
            try ItemDefinition(
                id: item.id,
                identity: ItemIdentity(name: item.name, itemTypes: item.modifiers, isBlocking: item.blocking),
                signals: Self.signals(item.signals),
                interactions: (item.interactions ?? []).map { interaction in
                    try InteractionDefinition(
                        id: interaction.id,
                        name: interaction.name,
                        advertisedBenefits: Self.signals(interaction.advertises).map {
                            MotiveBenefit(motiveType: $0.motiveType, expectedStrengthPerSecond: $0.strengthPerSecond)
                        },
                        motiveEffects: Self.signals(interaction.effects),
                        durationSeconds: interaction.duration,
                        requirements: InteractionRequirements(requiredPosture: interaction.posture),
                        script: interaction.script.map(script)
                    )
                },
                interactionCapacity: item.capacity ?? 1
            )
        }
    }

    /// Converts a motive-to-rate map into signals in `MotiveType` order.
    private static func signals(_ rates: [String: Double]?) throws -> [MotiveSignal] {
        guard let rates else {
            return []
        }
        for name in rates.keys where MotiveType(rawValue: name) == nil {
            throw ItemContentError.unknownMotive(name)
        }
        return MotiveType.allCases.compactMap { motiveType in
            rates[motiveType.rawValue].map { MotiveSignal(motiveType: motiveType, strengthPerSecond: $0) }
        }
    }
}

/// An invalid value in a pack's item content.
enum ItemContentError: Error, Equatable, CustomStringConvertible {
    case unknownMotive(String)

    var description: String {
        switch self {
        case let .unknownMotive(name):
            "Unknown motive '\(name)'."
        }
    }
}
