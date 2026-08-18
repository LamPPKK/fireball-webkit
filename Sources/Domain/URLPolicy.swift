import Foundation

enum URLPolicyError: LocalizedError, Equatable {
    case emptyInput
    case disallowedScheme(String)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .emptyInput: "Enter an address or search term."
        case .disallowedScheme(let scheme): "The \(scheme) scheme is not allowed."
        case .invalidURL: "The address could not be parsed."
        }
    }
}

struct URLPolicy: Sendable {
    private let allowedSchemes = Set(["http", "https"])

    func resolve(_ rawInput: String) throws -> URL {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw URLPolicyError.emptyInput }

        if let components = URLComponents(string: input), let scheme = components.scheme?.lowercased() {
            guard allowedSchemes.contains(scheme) else { throw URLPolicyError.disallowedScheme(scheme) }
            guard let url = components.url, url.host != nil else { throw URLPolicyError.invalidURL }
            return url
        }

        if input.contains(".") && !input.contains(" ") {
            guard let url = URL(string: "https://\(input)"), url.host != nil else { throw URLPolicyError.invalidURL }
            return url
        }

        var search = URLComponents(string: "https://duckduckgo.com/")!
        search.queryItems = [URLQueryItem(name: "q", value: input)]
        guard let url = search.url else { throw URLPolicyError.invalidURL }
        return url
    }

    func allowsNavigation(to url: URL?) -> Bool {
        guard let url, let scheme = url.scheme?.lowercased() else { return false }
        return allowedSchemes.contains(scheme) || (scheme == "about" && url.absoluteString == "about:blank")
    }
}
