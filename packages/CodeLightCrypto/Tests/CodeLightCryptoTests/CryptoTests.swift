import Testing
import Foundation
@testable import CodeLightCrypto

@Test func testMessageEncryptDecrypt() throws {
    let sharedSecret = Data("test-shared-secret-32-bytes-long".utf8)
    let crypto = MessageCrypto(sharedSecret: sharedSecret)

    let plaintext = "Hello, CodeLight!"
    let encrypted = try crypto.encrypt(plaintext)
    let decrypted = try crypto.decrypt(encrypted)

    #expect(decrypted == plaintext)
    #expect(encrypted != plaintext)
}

@Test func testDataEncryptDecrypt() throws {
    let sharedSecret = Data("another-secret-for-data-encrypt!".utf8)
    let crypto = MessageCrypto(sharedSecret: sharedSecret)

    let original = Data([0x01, 0x02, 0x03, 0xFF])
    let encrypted = try crypto.encryptData(original)
    let decrypted = try crypto.decryptData(encrypted)

    #expect(decrypted == original)
}

@Test func testDifferentKeysCannotDecrypt() throws {
    let crypto1 = MessageCrypto(sharedSecret: Data("key-one-32-bytes-long-pad-here!!".utf8))
    let crypto2 = MessageCrypto(sharedSecret: Data("key-two-32-bytes-long-pad-here!!".utf8))

    let encrypted = try crypto1.encrypt("secret message")

    #expect(throws: (any Error).self) {
        _ = try crypto2.decrypt(encrypted)
    }
}
