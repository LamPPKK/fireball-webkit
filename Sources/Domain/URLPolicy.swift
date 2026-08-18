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

enum NavigationDisposition: Equatable, Sendable {
    case web
    case externalConfirmation
    case blocked
}

struct URLPolicy: Sendable {
    let searchProvider: SearchProvider
    private let allowedSchemes = Set(["http", "https"])
    private let externalSchemes = Set(["mailto", "tel"])

    init(searchProvider: SearchProvider = .brave) {
        self.searchProvider = searchProvider
    }

    func resolve(_ rawInput: String) throws -> URL {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { throw URLPolicyError.emptyInput }

        if let components = URLComponents(string: input), let scheme = components.scheme?.lowercased() {
            guard allowedSchemes.contains(scheme) else { throw URLPolicyError.disallowedScheme(scheme) }
            guard let url = components.url, url.host != nil else { throw URLPolicyError.invalidURL }
            return url
        }

        if input.contains(".") && !input.contains(" ") {
            guard let url = URL(string: "https://\(input)"), url.host != nil else {
                throw URLPolicyError.invalidURL
            }
            return url
        }

        guard let url = searchProvider.searchURL(for: input) else { throw URLPolicyError.invalidURL }
        return url
    }

    func disposition(for url: URL?) -> NavigationDisposition {
        guard let url, let scheme = url.scheme?.lowercased() else { return .blocked }
        if allowedSchemes.contains(scheme) || (scheme == "about" && url.absoluteString == "about:blank") {
            return .web
        }
        if externalSchemes.contains(scheme) {
            return .externalConfirmation
        }
        return .blocked
    }

    func allowsNavigation(to url: URL?) -> Bool {
        disposition(for: url) == .web
    }
}
