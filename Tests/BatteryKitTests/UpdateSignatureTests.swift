#if canImport(CryptoKit)
import BatteryCore
import CryptoKit
import Foundation
import Testing

@testable import BatteryKit

/// Runs where CryptoKit exists (the macOS CI job); Linux has no CryptoKit.
@Suite struct UpdateSignatureTests {
    /// Stands in for a DMG.
    private let file = Data((0..<10_000).map { UInt8(truncatingIfNeeded: $0 &* 7 &+ 3) })

    private func verifier(for keys: Curve25519.Signing.PrivateKey...) throws -> UpdateSignatureVerifier {
        try #require(UpdateSignatureVerifier(publicKeysBase64: keys.map { base64($0) }))
    }

    private func base64(_ key: Curve25519.Signing.PrivateKey) -> String {
        key.publicKey.rawRepresentation.base64EncodedString()
    }

    @Test func acceptsTheSignatureOfTheMatchingKey() throws {
        let key = Curve25519.Signing.PrivateKey()
        let verifier = try verifier(for: key)
        let signature = try key.signature(for: file)
        #expect(verifier.isValid(signature: signature, for: file))
        // The .sig file as scripts/sign-update.swift writes it.
        let sigFile = Data((signature.base64EncodedString() + "\n").utf8)
        #expect(UpdateIntegrity.signature(fromSigFile: sigFile) == signature)
    }

    @Test func rejectsATamperedByte() throws {
        let key = Curve25519.Signing.PrivateKey()
        let verifier = try verifier(for: key)
        let signature = try key.signature(for: file)
        var tampered = file
        tampered[4321] ^= 0x01
        #expect(!verifier.isValid(signature: signature, for: tampered))
        var appended = file
        appended.append(0)
        #expect(!verifier.isValid(signature: signature, for: appended))
    }

    @Test func rejectsAnotherKeyAndBrokenSignatures() throws {
        let key = Curve25519.Signing.PrivateKey()
        let verifier = try verifier(for: key)
        let signature = try key.signature(for: file)
        let foreign = try Curve25519.Signing.PrivateKey().signature(for: file)
        #expect(!verifier.isValid(signature: foreign, for: file))
        var flipped = signature
        flipped[10] ^= 0x80
        #expect(!verifier.isValid(signature: flipped, for: file))
        #expect(!verifier.isValid(signature: Data(signature.prefix(63)), for: file))
        #expect(!verifier.isValid(signature: Data(), for: file))
    }

    @Test func refusesMalformedPublicKeys() {
        #expect(UpdateSignatureVerifier(publicKeysBase64: [""]) == nil)
        #expect(UpdateSignatureVerifier(publicKeysBase64: ["not base64"]) == nil)
        #expect(UpdateSignatureVerifier(publicKeysBase64: [Data(count: 31).base64EncodedString()]) == nil)
        #expect(UpdateSignatureVerifier(publicKeysBase64: []) == nil)
    }

    /// The rotation: version N trusts {K1, K2}, so the release signed with K2 installs; a version
    /// that trusts only K1 refuses it. Throwaway keys, never the release key.
    @Test func aListedSecondKeyVerifies() throws {
        let first = Curve25519.Signing.PrivateKey()
        let second = Curve25519.Signing.PrivateKey()
        let signature = try second.signature(for: file)
        #expect(try verifier(for: first, second).isValid(signature: signature, for: file))
        #expect(try verifier(for: second, first).isValid(signature: signature, for: file))
        #expect(try !verifier(for: first).isValid(signature: signature, for: file))
        // Listing a second key doesn't weaken the first.
        #expect(try verifier(for: first, second).isValid(signature: first.signature(for: file), for: file))
        let foreign = try Curve25519.Signing.PrivateKey().signature(for: file)
        #expect(try !verifier(for: first, second).isValid(signature: foreign, for: file))
    }

    @Test func anEmptyOrMalformedEntryIsIgnored() throws {
        let key = Curve25519.Signing.PrivateKey()
        let signature = try key.signature(for: file)
        let entries = ["", "  ", "not base64", Data(count: 31).base64EncodedString(), base64(key)]
        let verifier = try #require(UpdateSignatureVerifier(publicKeysBase64: entries))
        #expect(verifier.isValid(signature: signature, for: file))
        #expect(!verifier.isValid(signature: signature, for: file + [0]))
    }

    @Test func theBuiltInReleaseKeysLoad() {
        #expect(UpdateSignatureVerifier.release != nil)
    }

    @Test func sha256MatchesAKnownDigest() {
        #expect(
            UpdateSignatureVerifier.sha256Hex(of: Data("abc".utf8))
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
#endif
