/// Converts Robusta source text into its abstract syntax tree.
public protocol Frontend {
    func parse(_ source: String) throws -> [Statement]
}
