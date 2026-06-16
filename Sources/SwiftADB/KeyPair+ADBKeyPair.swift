// KeyPair+ADBKeyPair.swift
// SwiftADB — extends KeyPair to conform to ADBKeyPair so it can be used with ADBPairing.

import Foundation
import Security
import ADBPairing

extension KeyPair: ADBKeyPair {
    // MARK: - secIdentity

    public func secIdentity() throws -> sec_identity_t {
        guard let cert = certificate else {
            throw NSError(domain: "KeyPair", code: 10,
                          userInfo: [NSLocalizedDescriptionKey:
                            "KeyPair has no certificate — generate one with KeyPair.generateWithCertificate()"])
        }
        var identity: SecIdentity?
        let status = SecIdentityCreateWithCertificate(nil, cert, &identity)
        guard status == errSecSuccess, let id = identity else {
            // Try to wrap manually
            throw NSError(domain: "KeyPair", code: 11,
                          userInfo: [NSLocalizedDescriptionKey:
                            "Could not create SecIdentity (status \(status))"])
        }
        return sec_identity_create(id)!
    }

    // MARK: - encodedPublicKey

    public func encodedPublicKey(deviceName: String) throws -> Data {
        let raw = try AndroidPubkey.encode(publicKey: publicKey)
        let b64 = raw.base64EncodedString()
        let formatted = b64 + " " + deviceName + "\0"
        return Data(formatted.utf8)
    }
}
