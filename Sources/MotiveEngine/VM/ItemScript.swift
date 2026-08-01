import Foundation

struct ItemScriptError: Error, CustomStringConvertible, Equatable {
    let message: String
    let line: Int
    
    var description: String {
        "line \(line): \(message)"
    }
}
