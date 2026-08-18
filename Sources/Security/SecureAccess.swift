import Foundation
import LocalAuthentication
import Security

protocol SecretStoring: Sendable {
    func store(_ data: Data, account: String) throws
    func load(account: String) throws -> Data?
    func delete(account: String) throws
}

struct KeychainSecretStore: SecretStoring {
    let service: String

    func store(_ data: Data, account: String) throws {
        try delete(account: account)
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData: data,
        ] as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecureAccessError.keychain(status) }
    }

    func load(account: String) throws -> Data? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ] as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw SecureAccessError.keychain(status) }
        return data
    }

    func delete(account: String) throws {
        let status = SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecureAccessError.keychain(status) }
    }
}

protocol OwnerAuthenticating: Sendable {
    func authenticate(reason: String) async throws
}

struct LocalOwnerAuthenticator: OwnerAuthenticating {
    func authenticate(reason: String) async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? SecureAccessError.authenticationUnavailable
        }
        guard try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) else {
            throw SecureAccessError.authenticationFailed
        }
    }
}

enum SecureAccessError: Error, Equatable {
    case keychain(OSStatus)
    case authenticationUnavailable
    case authenticationFailed
}
