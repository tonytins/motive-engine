import Foundation

enum Needs: String, CaseIterable, Hashable, Codable {
    case hunger
    case energy
    case hygiene
    case bladder
    case social
    case fun
}

enum Items: String, CaseIterable, Hashable, Codable {
    case fridge
    case bed
    case shower
    case toilet
    case phone
    case tv
}
