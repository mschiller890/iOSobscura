import Foundation

public enum ObscuraError: Error, LocalizedError, Sendable {
    case network(String)
    case invalidResponse
    case notFound
    case parsingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .network(let message):
            return "Couldn't reach iosapps.litten.ca: \(message)"
        case .invalidResponse:
            return "The server sent back something this app doesn't understand."
        case .notFound:
            return "That location doesn't exist."
        case .parsingFailed(let detail):
            return "Couldn't read the server's response (\(detail))."
        }
    }
}
