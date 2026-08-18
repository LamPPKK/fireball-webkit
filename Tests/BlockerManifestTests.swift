import CryptoKit
import WebKit
import XCTest
@testable import FireballWebKit

@MainActor
final class BlockerManifestTests: XCTestCase {
    func testSignedManifestAcceptsMatchingArtifact() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let artifact = Data("[]".utf8)
        let payload = payload(for: artifact)
        let signature = try privateKey.signature(for: payload.canonicalData()).base64EncodedString()
        let verifier = try BlockerVerifier(rawPublicKey: privateKey.publicKey.rawRepresentation)

        XCTAssertNoThrow(
            try verifier.verify(
                BlockerManifest(payload: payload, signature: signature),
                artifacts: [payload.artifacts[0].url: artifact],
                appVersion: "0.1.0"
            )
        )
    }

    func testChecksumMismatchRejectsArtifactBeforeInstall() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let artifact = Data("[]".utf8)
        let payload = payload(for: artifact)
        let signature = try privateKey.signature(for: payload.canonicalData()).base64EncodedString()
        let verifier = try BlockerVerifier(rawPublicKey: privateKey.publicKey.rawRepresentation)

        XCTAssertThrowsError(
            try verifier.verify(
                BlockerManifest(payload: payload, signature: signature),
                artifacts: [payload.artifacts[0].url: Data("[{}]".utf8)],
                appVersion: "0.1.0"
            )
        ) { error in
            XCTAssertEqual(error as? ContentRuleError, .checksumMismatch)
        }
    }

    func testUntrustedSameVersionManifestCannotSuppressVerification() async throws {
        let trustedKey = Curve25519.Signing.PrivateKey()
        let attackerKey = Curve25519.Signing.PrivateKey()
        let artifact = Data("[]".utf8)
        let payload = payload(for: artifact)
        let manifest = BlockerManifest(
            payload: payload,
            signature: try attackerKey.signature(for: payload.canonicalData()).base64EncodedString()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        let manifestURL = URL(string: "https://updates.example/manifest.json")!
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "BlockerManifestTests.\(UUID())"))
        defaults.set(payload.version, forKey: "blocker.activeVersion")
        let updater = BlockerUpdateService(
            compiler: RejectingRuleCompiler(),
            httpClient: StaticBlockerHTTPClient(responses: [manifestURL: manifestData]),
            verifier: try BlockerVerifier(rawPublicKey: trustedKey.publicKey.rawRepresentation),
            defaults: defaults,
            appVersion: "0.1.0"
        )

        do {
            _ = try await updater.update(from: manifestURL, force: true)
            XCTFail("Expected signature rejection")
        } catch {
            XCTAssertEqual(error as? ContentRuleError, .signatureInvalid)
        }
    }

    private func payload(for artifact: Data) -> BlockerManifestPayload {
        BlockerManifestPayload(
            schemaVersion: 1,
            version: "2026.08.19.1",
            sourceCommits: ["easylist": String(repeating: "a", count: 40)],
            artifacts: [
                BlockerArtifact(
                    identifier: "easylist-001",
                    url: URL(string: "https://github.com/LamPPKK/fireball-webkit/releases/download/rules/rules.json")!,
                    sha256: SHA256.hash(data: artifact).map { String(format: "%02x", $0) }.joined()
                )
            ],
            minimumAppVersion: "0.1.0",
            createdAt: Date(timeIntervalSince1970: 1_776_700_000)
        )
    }
}

private struct StaticBlockerHTTPClient: BlockerHTTPClient {
    let responses: [URL: Data]

    func data(from url: URL, maximumBytes: Int) async throws -> Data {
        guard let data = responses[url] else { throw ContentRuleError.downloadFailed }
        guard data.count <= maximumBytes else { throw ContentRuleError.downloadTooLarge }
        return data
    }
}

@MainActor
private struct RejectingRuleCompiler: ContentRuleCompiling {
    func compile(identifier: String, encodedRules: String) async throws -> WKContentRuleList {
        throw ContentRuleError.compilationReturnedNoRule
    }

    func lookup(identifier: String) async throws -> WKContentRuleList? {
        nil
    }
}
