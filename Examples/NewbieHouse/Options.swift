import Foundation

/// The example's command-line options.
struct Options {
    var loadsBrokenMod = false
    var lotURL: URL?
    var extraPackFolders: [URL] = []

    init(arguments: [String]) throws {
        var remaining = arguments[...]
        while let argument = remaining.popFirst() {
            switch argument {
            case "--broken-mod":
                loadsBrokenMod = true
            case "--lot":
                guard let path = remaining.popFirst() else {
                    throw NewbieHouseError.missingValue("--lot")
                }
                lotURL = URL(fileURLWithPath: path)
            default:
                extraPackFolders.append(URL(fileURLWithPath: argument))
            }
        }
    }
}

/// Problems the example reports before or while setting up the simulation.
enum NewbieHouseError: Error {
    case missingResource(String)
    case missingValue(String)
    case invalidIdentifier(String)
    case packFailedToLoad(folder: String, reason: String)
}
