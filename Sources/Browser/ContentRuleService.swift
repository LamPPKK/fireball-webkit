import Foundation
import WebKit

@MainActor
protocol ContentRuleCompiling {
    func compile(identifier: String, encodedRules: String) async throws -> WKContentRuleList
}

@MainActor
struct ContentRuleService: ContentRuleCompiling {
    func compile(identifier: String, encodedRules: String) async throws -> WKContentRuleList {
        guard encodedRules.utf8.count <= 8 * 1024 * 1024 else {
            throw ContentRuleError.rulesTooLarge
        }
        let compiled = try await WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: encodedRules
        )
        guard let compiled else { throw ContentRuleError.compilationReturnedNoRule }
        return compiled
    }
}

enum ContentRuleError: Error, Equatable {
    case rulesTooLarge
    case checksumMismatch
    case signatureInvalid
    case compilationReturnedNoRule
}
