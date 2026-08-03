// Basil
import Foundation

let scriptKeywords: Set<String> = [
    "let", "emit", "if", "then", "else", "end", "and", "or", "not",
    "true", "false", "hasmodifier"
]

struct ItemScriptError: Error, CustomStringConvertible, Equatable {
    let message: String
    let line: Int
    
    var description: String {
        "line \(line): \(message)"
    }
}

enum Keyword: String, CaseIterable, Equatable  {
        case val, mut, emit, match, end
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

