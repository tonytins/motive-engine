import Foundation

struct Parser {
    let tokens: [Token]
    var position = 0
    
    init(tokens: [Token]) {
        self.tokens = tokens
    }
    
    mutating func parse() throws -> [StateDecl] {
        var states: [StateDecl] = []
        
    }
}
