// SPAKE2Tests.swift
// Tests for the SPAKE2 + PairingAuthCtx implementation.
// Validates that Alice and Bob derive the same shared key given the same password.

import Testing
import Foundation
@testable import ADBPairing

@Suite("SPAKE2 Protocol Tests")
struct SPAKE2Tests {

    // MARK: - Basic round-trip

    @Test("Alice and Bob derive the same 64-byte key")
    func testAliceBobKeyAgreement() throws {
        let password = Array("123456".utf8)

        let alice = SPAKE2Context(role: .alice,
                                  myName: Array("adb pair client\0".utf8),
                                  theirName: Array("adb pair server\0".utf8))
        let bob   = SPAKE2Context(role: .bob,
                                  myName: Array("adb pair server\0".utf8),
                                  theirName: Array("adb pair client\0".utf8))

        // Generate messages
        let aliceMsg = try alice.generateMessage(password: password)
        let bobMsg   = try bob.generateMessage(password: password)

        #expect(aliceMsg.count == 32, "Alice message must be 32 bytes")
        #expect(bobMsg.count == 32,   "Bob message must be 32 bytes")

        // Process messages
        let aliceKey = try alice.processMessage(bobMsg)
        let bobKey   = try bob.processMessage(aliceMsg)

        #expect(aliceKey.count == 64, "Key must be 64 bytes")
        #expect(aliceKey == bobKey,   "Alice and Bob must derive the same key")
    }

    // MARK: - Wrong password

    @Test("Different passwords produce different keys")
    func testWrongPassword() throws {
        let alicePass = Array("123456".utf8)
        let bobPass   = Array("654321".utf8)

        let alice = SPAKE2Context(role: .alice,
                                  myName: Array("adb pair client\0".utf8),
                                  theirName: Array("adb pair server\0".utf8))
        let bob   = SPAKE2Context(role: .bob,
                                  myName: Array("adb pair server\0".utf8),
                                  theirName: Array("adb pair client\0".utf8))

        let aliceMsg = try alice.generateMessage(password: alicePass)
        let bobMsg   = try bob.generateMessage(password: bobPass)
        let aliceKey = try alice.processMessage(bobMsg)
        let bobKey   = try bob.processMessage(aliceMsg)

        #expect(aliceKey != bobKey, "Different passwords must produce different keys")
    }

    // MARK: - PairingAuthCtx round-trip

    @Test("PairingAuthCtx: encrypt/decrypt round-trip after SPAKE2")
    func testPairingAuthCtxEncryptDecrypt() throws {
        let password = Array("test_password".utf8)

        let alice = try PairingAuthCtx.createAlice(password: password)
        let bob   = try PairingAuthCtx.createBob(password: password)

        // Exchange SPAKE2 msgs and derive symmetric key
        try alice.initCipher(peerMsg: bob.msg)
        try bob.initCipher(peerMsg: alice.msg)

        // Alice encrypts, Bob decrypts
        let plaintext  = Array("Hello from Alice!".utf8)
        let ciphertext = try alice.encrypt(plaintext)
        let recovered  = try bob.decrypt(ciphertext)

        #expect(recovered == plaintext, "Round-trip encrypt/decrypt must recover plaintext")
    }

    // MARK: - Field arithmetic sanity

    @Test("Ed25519 field: 1 + 1 == 2")
    func testFieldAddition() {
        let one = Ed25519FieldElement.one
        let two = one + one
        let twoBytes = two.toBytes()
        #expect(twoBytes[0] == 2)
        twoBytes.dropFirst().forEach { #expect($0 == 0) }
    }

    @Test("Ed25519 field: a * a^(-1) == 1")
    func testFieldInversion() {
        var b = [UInt8](repeating: 0, count: 32)
        b[0] = 7
        let f = Ed25519FieldElement.fromBytes(b)
        let fi = f.invert()
        let product = f * fi
        let expected = Ed25519FieldElement.one
        #expect(product == expected, "f * f^-1 must equal 1")
    }

    // MARK: - Scalar reduction

    @Test("Scalar25519.reduce output is 32 bytes")
    func testScalarReduce() {
        var s = [UInt8](repeating: 0xFF, count: 64)
        Scalar25519.reduce(&s)
        // After reduction the top bytes should be zeroed (reduced mod l)
        #expect(s[31] < 0x11, "Top byte of reduced scalar must be < 0x11")
    }

    // MARK: - generateMessage error handling

    @Test("generateMessage throws if called twice")
    func testGenerateMessageTwice() throws {
        let ctx = SPAKE2Context(role: .alice,
                                myName: Array("a".utf8),
                                theirName: Array("b".utf8))
        _ = try ctx.generateMessage(password: Array("pw".utf8))
        #expect(throws: SPAKE2Error.self) {
            _ = try ctx.generateMessage(password: Array("pw".utf8))
        }
    }

    @Test("processMessage throws before generateMessage")
    func testProcessMessageBeforeGenerate() throws {
        let ctx = SPAKE2Context(role: .alice,
                                myName: Array("a".utf8),
                                theirName: Array("b".utf8))
        #expect(throws: SPAKE2Error.self) {
            _ = try ctx.processMessage([UInt8](repeating: 0, count: 32))
        }
    }
}
