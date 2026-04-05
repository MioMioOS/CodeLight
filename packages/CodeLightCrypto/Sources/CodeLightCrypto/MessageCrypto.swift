import Foundation
import CryptoKit

/// Encrypts and decrypts messages using ChaChaPoly (CryptoKit).
/// Each message gets a unique nonce. The shared key is derived during pairing.
public struct MessageCrypto: Sendable {

    private let symmetricKey: SymmetricKey

    public init(sharedSecret: Data) {
        // Derive a 256-bit key from the shared secret
        let derived = SHA256.hash(data: sharedSecret)
        self.symmetricKey = SymmetricKey(data: derived)
    }

    /// Encrypt a string message. Returns base64-encoded ciphertext.
    public func encrypt(_ plaintext: String) throws -> String {
        let data = Data(plaintext.utf8)
        let sealed = try ChaChaPoly.seal(data, using: symmetricKey)
        return sealed.combined.base64EncodedString()
    }

    /// Decrypt a base64-encoded ciphertext back to string.
    public func decrypt(_ ciphertext: String) throws -> String {
        guard let data = Data(base64Encoded: ciphertext) else {
            throw CryptoError.invalidBase64
        }
        let box = try ChaChaPoly.SealedBox(combined: data)
        let decrypted = try ChaChaPoly.open(box, using: symmetricKey)
        guard let text = String(data: decrypted, encoding: .utf8) else {
            throw CryptoError.invalidUTF8
        }
        return text
    }

    /// Encrypt raw data. Returns combined nonce+ciphertext+tag.
    public func encryptData(_ data: Data) throws -> Data {
        let sealed = try ChaChaPoly.seal(data, using: symmetricKey)
        return sealed.combined
    }

    /// Decrypt raw data.
    public func decryptData(_ data: Data) throws -> Data {
        let box = try ChaChaPoly.SealedBox(combined: data)
        return try ChaChaPoly.open(box, using: symmetricKey)
    }
}

public enum CryptoError: Error {
    case invalidBase64
    case invalidUTF8
}
