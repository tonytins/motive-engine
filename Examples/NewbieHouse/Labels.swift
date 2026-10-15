import MotiveEngine

/// Player-facing names and map symbols for the Sims and items on the lot.
struct Labels {
    static let familyName = "Newbie"

    private let simNames: [SimID: String]
    private let itemNames: [ItemInstanceID: String]
    private let symbols: [ItemInstanceID: Character]
    private let catalog: ItemDefinitionCatalog

    init(layout: LotLayout, skippedItems: [LotLayout.ItemPlacement], catalog: ItemDefinitionCatalog) {
        let skipped = Set(skippedItems.map(\.id))
        var itemNames: [ItemInstanceID: String] = [:]
        var symbols: [ItemInstanceID: Character] = [:]
        for item in layout.items where !skipped.contains(item.id) {
            let name = catalog.definition(for: item.definitionID)?.identity.name ?? item.id.rawValue
            itemNames[item.id] = name
            // Each item gets the first letter of its name not already in use.
            let used = Set(symbols.values)
            symbols[item.id] = name.lowercased().first { $0.isLetter && !used.contains($0) } ?? "#"
        }

        simNames = Dictionary(uniqueKeysWithValues: layout.sims.map { ($0.id, "\($0.name) \(Self.familyName)") })
        self.itemNames = itemNames
        self.symbols = symbols
        self.catalog = catalog
    }

    func name(of simID: SimID) -> String {
        simNames[simID] ?? simID.rawValue
    }

    func name(of itemID: ItemInstanceID) -> String {
        itemNames[itemID] ?? itemID.rawValue
    }

    func name(of interaction: InteractionReference) -> String {
        catalog.definition(for: interaction.itemDefinitionID)?.identity.name ?? interaction.itemDefinitionID.rawValue
    }

    func symbol(of itemID: ItemInstanceID) -> Character {
        symbols[itemID] ?? "#"
    }

    /// Sims are numbered in snapshot order; items use their letter.
    func legend(for snapshot: SimulationSnapshot) -> String {
        let sims = snapshot.sims.enumerated().map { "\($0.offset + 1)=\(name(of: $0.element.id))" }
        let items = itemNames.sorted { $0.value < $1.value }.map { "\(symbol(of: $0.key))=\($0.value)" }
        return (sims + items).joined(separator: " ")
    }
}
