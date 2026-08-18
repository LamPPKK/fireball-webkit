import XCTest
@testable import FireballWebKit

final class URLPolicyTests: XCTestCase {
    func testAddsHTTPSForHostname() throws {
        XCTAssertEqual(try URLPolicy().resolve("example.com").absoluteString, "https://example.com")
    }

    func testBuildsEncodedSearchURL() throws {
        let url = try URLPolicy().resolve("private browser")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "duckduckgo.com")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, "private browser")
    }

    func testRejectsScriptAndFileSchemes() {
        XCTAssertThrowsError(try URLPolicy().resolve("javascript:alert(1)"))
        XCTAssertThrowsError(try URLPolicy().resolve("file:///etc/passwd"))
    }

    func testNavigationDelegatePolicyRejectsNonWebSchemes() throws {
        let policy = URLPolicy()
        XCTAssertTrue(policy.allowsNavigation(to: try XCTUnwrap(URL(string: "https://example.com"))))
        XCTAssertTrue(policy.allowsNavigation(to: try XCTUnwrap(URL(string: "about:blank"))))
        XCTAssertFalse(policy.allowsNavigation(to: try XCTUnwrap(URL(string: "data:text/html,secret"))))
        XCTAssertFalse(policy.allowsNavigation(to: try XCTUnwrap(URL(string: "fireball://profile"))))
    }
}
