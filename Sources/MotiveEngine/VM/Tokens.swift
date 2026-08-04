import Foundation

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

private enum Keyword: String, CaseIterable, Equatable {
    case val, mut, emit, match, end
    case state
    case function = "func"
    case and, or, not
    case trueLiteral = "true"
    case falseLiteral = "false"
    case none = "None"
    case hasModifier = "hasmodifier"
    case wildcard = "_"
    case hunger = "Hunger"
    case energy = "Energy"
    case hygiene = "Hygiene"
    case bladder = "Bladder"
    case social = "Social"
    case fun = "Fun"
    
    init?(matching text: String) {
        let lower = text.lowercased()
        guard let match = Keyword.allCases.first(
            where: {
                $0.rawValue.lowercased() == lower
            }
        ) else {
            return nil
        }
        
        self = match
    }
    
}

extension Keyword {
    var motiveType: MotiveType? {
        switch self {
        case .hunger: return .hunger
        case .energy: return .energy
        case .hygiene: return .hygiene
        case .bladder: return .bladder
        case .social: return .social
        case .fun: return .fun
        default: return nil
        }
    }
}

