enum TokenKind: Equatable {
    case number(Double)
    case string(String)
    case identifier(String)
    case keyword(String)
    case symbol(String)
    case newline
    case endOfInput
}

struct Token: Equatable {
    let kind: TokenKind
    let line: Int
}
