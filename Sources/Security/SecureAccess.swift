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
    case accessControlCreationFailed
}

@MainActor
protocol ProfileLocking: AnyObject {
    func isEnabled(for profileID: ProfileID) -> Bool
    func enable(for profileID: ProfileID) throws
    func disable(for profileID: ProfileID) throws
    func unlock(profileID: ProfileID, reason: String) async throws
}

@MainActor
final class KeychainProfileLockStore: ProfileLocking {
    private let service: String
    private let defaults: UserDefaults

    init(service: String, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    func isEnabled(for profileID: ProfileID) -> Bool {
        defaults.bool(forKey: enabledKey(profileID))
    }

    func enable(for profileID: ProfileID) throws {
        try disable(for: profileID)
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            _ = error?.takeRetainedValue()
            throw SecureAccessError.accessControlCreationFailed
        }

        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(profileID),
            kSecAttrAccessControl: accessControl,
            kSecValueData: Data(UUID().uuidString.utf8),
        ] as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecureAccessError.keychain(status) }
        defaults.set(true, forKey: enabledKey(profileID))
    }

    func disable(for profileID: ProfileID) throws {
        let status = SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(profileID),
        ] as CFDictionary)
        guard Self.isTerminalDeletionStatus(status) else {
            throw SecureAccessError.keychain(status)
        }
        defaults.removeObject(forKey: enabledKey(profileID))
    }

    static func isTerminalDeletionStatus(_ status: OSStatus) -> Bool {
        status == errSecSuccess || status == errSecItemNotFound
    }

    func unlock(profileID: ProfileID, reason: String) async throws {
        guard isEnabled(for: profileID) else { return }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedReason = reason
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(profileID),
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context,
        ] as CFDictionary, &result)
        guard status == errSecSuccess, result is Data else {
            if status == errSecUserCanceled || status == errSecAuthFailed {
                throw SecureAccessError.authenticationFailed
            }
            throw SecureAccessError.keychain(status)
        }
    }

    private func account(_ profileID: ProfileID) -> String {
        "profile-lock.\(profileID.rawValue.uuidString.lowercased())"
    }

    private func enabledKey(_ profileID: ProfileID) -> String {
        "profile-lock.enabled.\(profileID.rawValue.uuidString.lowercased())"
    }
}
