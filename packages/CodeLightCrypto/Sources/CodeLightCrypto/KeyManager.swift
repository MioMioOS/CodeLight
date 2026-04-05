import Foundation
import CryptoKit

/// Manages Ed25519 keypairs and encryption keys.
/// Keys are stored in the Keychain for persistence.
public final class KeyManager: Sendable {

    private let serviceName: String

    public init(serviceName: String = "com.codelight.keys") {
        self.serviceName = serviceName
    }

    // MARK: - Ed25519 Identity Key

    /// Generate a new Ed25519 signing keypair and store in Keychain.
    public func generateIdentityKey() throws -> Curve25519.Signing.PublicKey {
        let privateKey = Curve25519.Signing.PrivateKey()
        try saveToKeychain(key: "identity-private", data: privateKey.rawRepresentation)
        return privateKey.publicKey
    }

    /// Load the existing identity private key from Keychain.
    public func loadIdentityPrivateKey() throws -> Curve25519.Signing.PrivateKey? {
        guard let data = loadFromKeychain(key: "identity-private") else { return nil }
        return try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    /// Get or create identity keypair. Returns public key.
    public func getOrCreateIdentityKey() throws -> Curve25519.Signing.PublicKey {
        if let existing = try loadIdentityPrivateKey() {
            return existing.publicKey
        }
        return try generateIdentityKey()
    }

    // MARK: - Signing

    /// Sign data with the identity private key.
    public func sign(_ data: Data) throws -> Data {
        guard let privateKey = try loadIdentityPrivateKey() else {
            throw KeyManagerError.noIdentityKey
        }
        return try privateKey.signature(for: data)
    }

    /// Get public key as base64 string.
    public func publicKeyBase64() throws -> String {
        let publicKey = try getOrCreateIdentityKey()
        return publicKey.rawRepresentation.base64EncodedString()
    }

    // MARK: - Encryption Key Storage (for paired devices)

    /// Store an encryption key for a specific server/device pair.
    public func storeEncryptionKey(_ key: Data, forServer serverUrl: String) throws {
        let keychainKey = "enc-\(serverUrl.hashValue)"
        try saveToKeychain(key: keychainKey, data: key)
    }

    /// Load encryption key for a server.
    public func loadEncryptionKey(forServer serverUrl: String) -> Data? {
        let keychainKey = "enc-\(serverUrl.hashValue)"
        return loadFromKeychain(key: keychainKey)
    }

    // MARK: - Token Storage

    /// Store auth token for a server.
    public func storeToken(_ token: String, forServer serverUrl: String) throws {
        let keychainKey = "token-\(serverUrl.hashValue)"
        try saveToKeychain(key: keychainKey, data: Data(token.utf8))
    }

    /// Load auth token for a server.
    public func loadToken(forServer serverUrl: String) -> String? {
        guard let data = loadFromKeychain(key: "token-\(serverUrl.hashValue)") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeyManagerError.keychainError(status)
        }
    }

    private func loadFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
}

public enum KeyManagerError: Error {
    case noIdentityKey
    case keychainError(OSStatus)
}
