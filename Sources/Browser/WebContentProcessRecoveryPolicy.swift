import Foundation

enum WebContentProcessRecoveryDecision: Equatable {
    case reload
    case discard
    case reportFailure
}

struct WebContentProcessRecoveryPolicy {
    private var attemptedAutomaticReload = false

    mutating func decision(isActive: Bool, hasRestorableURL: Bool) -> WebContentProcessRecoveryDecision {
        guard isActive else { return .discard }
        guard hasRestorableURL, !attemptedAutomaticReload else { return .reportFailure }
        attemptedAutomaticReload = true
        return .reload
    }

    mutating func navigationDidFinish() {
        attemptedAutomaticReload = false
    }

    mutating func userRequestedReload() {
        attemptedAutomaticReload = false
    }
}
