import Foundation
import XCTest
@testable import FireballWebKit

final class SecureAccessTests: XCTestCase {
    func testAuthenticationCancellationIsPropagated() async {
        let authenticator = FakeOwnerAuthenticator(result: .failure(CancellationError()))
        do {
            try await authenticator.authenticate(reason: "Unlock private profile")
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }
}

private struct FakeOwnerAuthenticator: OwnerAuthenticating {
    let result: Result<Void, any Error>

    func authenticate(reason: String) async throws {
        _ = reason
        try result.get()
    }
}
