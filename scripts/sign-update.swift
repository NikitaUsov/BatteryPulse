// Signs a release DMG for BatteryPulse's in-app updater, and checks such signatures (macOS).
//
//   UPDATE_SIGNING_KEY=<private key> swift scripts/sign-update.swift build/BatteryPulse.dmg
//       Writes build/BatteryPulse.dmg.sig: the base64 Ed25519 signature of the file's bytes.
//   swift scripts/sign-update.swift --verify <file> <public key>
//       Checks <file>.sig against a public key; exits with 1 if it doesn't verify.
//   UPDATE_SIGNING_KEY=<private key> swift scripts/sign-update.swift --public-key
//       Prints the public key of the private key.
//   swift scripts/sign-update.swift --generate-key
//       Prints a new private key. Keep it secret: it becomes the UPDATE_SIGNING_KEY secret of the
//       `release` environment (not a repository secret; see release.yml), and its public key goes
//       into ReleaseSigning.publicKeys in Sources/BatteryCore/ReleaseSigning.swift.
//   swift scripts/sign-update.swift --help
//       Prints this usage and how to rotate the key.
//
// Keys are raw 32-byte Curve25519 signing keys in base64, as CryptoKit's `rawRepresentation`.
// The app installs an update itself only if a public key built into it verifies the
// signature, so a DMG replaced on GitHub without one of those keys is refused.
import CryptoKit
import Foundation

let usage = """
    usage: swift scripts/sign-update.swift <file>
           swift scripts/sign-update.swift --verify <file> <public key>
           swift scripts/sign-update.swift --public-key
           swift scripts/sign-update.swift --generate-key
           swift scripts/sign-update.swift --help
    """

let rotation = """
    Rotating the key: the app trusts every key in ReleaseSigning.publicKeys, and release.yml
    refuses a secret whose key isn't listed. Version N lists the current key K1 and the next key
    K2 and is still signed with K1. Version N+1 is signed with K2: put K2's private key into the
    UPDATE_SIGNING_KEY secret of the release environment. Versions from N on install it in-app;
    older ones, which trust only K1, show the release page instead. A later version drops K1
    from the list. Releases are signed only by the release workflow, never by hand, and nobody
    else asks for or handles the private key.
    """

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

/// The key in UPDATE_SIGNING_KEY.
func signingKey() -> Curve25519.Signing.PrivateKey {
    let text = (ProcessInfo.processInfo.environment["UPDATE_SIGNING_KEY"] ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { fail("UPDATE_SIGNING_KEY is not set or empty") }
    guard let raw = Data(base64Encoded: text), raw.count == 32,
        let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw)
    else { fail("UPDATE_SIGNING_KEY is not a base64 raw 32-byte Curve25519 private key") }
    return key
}

func publicKey(_ text: String) -> Curve25519.Signing.PublicKey {
    guard let raw = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)), raw.count == 32,
        let key = try? Curve25519.Signing.PublicKey(rawRepresentation: raw)
    else { fail("'\(text)' is not a base64 raw 32-byte Curve25519 public key") }
    return key
}

func contents(of path: String) -> Data {
    guard let data = FileManager.default.contents(atPath: path) else { fail("can't read \(path)") }
    return data
}

func base64(_ key: Curve25519.Signing.PublicKey) -> String {
    key.rawRepresentation.base64EncodedString()
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "--help" where arguments.count == 1:
    print(usage + "\n\n" + rotation)

case "--generate-key" where arguments.count == 1:
    print(Curve25519.Signing.PrivateKey().rawRepresentation.base64EncodedString())

case "--public-key" where arguments.count == 1:
    print(base64(signingKey().publicKey))

case "--verify" where arguments.count == 3:
    let path = arguments[1]
    let key = publicKey(arguments[2])
    let text = String(decoding: contents(of: path + ".sig"), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let signature = Data(base64Encoded: text), signature.count == 64 else {
        fail("\(path).sig doesn't hold a base64 64-byte signature")
    }
    guard key.isValidSignature(signature, for: contents(of: path)) else {
        fail("the signature in \(path).sig doesn't match \(path) and the key \(base64(key))")
    }
    print("\(path).sig is a valid signature by \(base64(key))")

case let path? where arguments.count == 1 && !path.hasPrefix("-"):
    let key = signingKey()
    let file = contents(of: path)
    let signature: Data
    do {
        signature = try key.signature(for: file)
    } catch {
        fail("signing \(path) failed: \(error)")
    }
    // Check it the way the app will before publishing it.
    guard key.publicKey.isValidSignature(signature, for: file) else { fail("the new signature doesn't verify") }
    do {
        try Data((signature.base64EncodedString() + "\n").utf8).write(to: URL(fileURLWithPath: path + ".sig"))
    } catch {
        fail("can't write \(path).sig: \(error)")
    }
    print("Signed \(path) (\(file.count) bytes) with the key whose public key is \(base64(key.publicKey))")

default:
    fail(usage)
}
