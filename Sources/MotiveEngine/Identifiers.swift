/// A stable, nonempty string that identifies a value.
///
/// Conforming types encode and decode as a single string and reject empty
/// strings both when created and when decoded.
public protocol StringIdentifier: Codable, Hashable, Sendable {
    /// The underlying identifier.
    var rawValue: String { get }

    /// Creates an identifier, or returns `nil` when `rawValue` is empty.
    init?(_ rawValue: String)
}

extension StringIdentifier {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let identifier = Self(rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "\(Self.self) must not be empty"
            )
        }
        self = identifier
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
