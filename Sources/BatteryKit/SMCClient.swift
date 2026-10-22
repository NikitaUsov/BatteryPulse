#if os(macOS)
import BatteryCore
import Foundation
import IOKit
import os

/// A read-only client of the AppleSMC user client. It works without root or entitlements in an
/// app that isn't sandboxed, and only ever sends the read commands of ``SMCParamBlock/Command``
/// through selector 2: never a write, never selectors 0 and 1.
///
/// A call takes about 0.2–0.5 ms (at worst ~11 ms on an M4 Max), and key info is cached, so the
/// 16 battery keys take about 3–8 ms on the main actor (derived from the call time, not
/// measured), and a poll's two live keys about 0.4–1 ms.
@MainActor
public final class SMCClient {
    public enum Failure: Error, Equatable {
        case serviceNotFound
        case open(kern_return_t)
        case call(kern_return_t)
        case truncatedReply(Int)
        case keyNotFound(SMCFourCC)
        case unreadable(SMCFourCC)
        case unsupportedSize(SMCFourCC, UInt32)
        case smc(SMCFourCC, result: UInt8)
    }

    /// `IOConnectCallStructMethod` selector 2 (`kSMCHandleYPCEvent`); the command rides in `data8`.
    private static let selector: UInt32 = 2

    /// `kIOReturnNotPrivileged`: this key needs an entitlement we don't have.
    private static let notPrivileged = kern_return_t(bitPattern: 0xE000_02C1)
    /// Errors that mean the connection itself is gone (`MACH_SEND_INVALID_DEST`,
    /// `kIOReturnNotOpen`, `kIOReturnNoDevice`), so it is reopened on the next call. Any other
    /// error belongs to the one key.
    private static let connectionLost: Set<kern_return_t> = [
        0x1000_0003, kern_return_t(bitPattern: 0xE000_02CD), kern_return_t(bitPattern: 0xE000_02C0),
    ]

    /// The open connection, or 0.
    private var port: io_connect_t = 0
    private var keyInfo: [SMCFourCC: SMCKeyInfo] = [:]
    /// Keys this Mac doesn't have; they're never asked about again.
    private var missing: Set<SMCFourCC> = []
    /// Keys whose failure was logged this session (``logOnce(_:reason:)``).
    private var loggedFailures: Set<SMCFourCC> = []
    private var isUnavailable = false

    public init() {}

    // A plain deinit may read `port`: it is Sendable, and nothing else can touch the client by now.
    deinit {
        if port != 0 { IOServiceClose(port) }
    }

    /// The listed keys this Mac has and lets us read. Missing keys are remembered, so after the
    /// first call this costs one round trip per present key.
    public func read(_ keys: [SMCFourCC]) -> [SMCRawValue] {
        keys.compactMap { key in
            guard !isUnavailable, !missing.contains(key) else { return nil }
            do throws(Failure) {
                return try read(key)
            } catch {
                note(error, for: key)
                return nil
            }
        }
    }

    /// What a failed read of `key` means for the next reads, logged in the `smc` category. Keys and
    /// codes are public: they come from the code and the SMC, never from the user.
    private func note(_ failure: Failure, for key: SMCFourCC) {
        let name = key.description
        switch failure {
        case .serviceNotFound:
            isUnavailable = true  // no AppleSMC, as in a virtual machine: stop trying
            Diagnostics.smc.notice("No AppleSMC service; the SMC's battery keys are not read")
        case .open(let status):
            isUnavailable = true  // the sandbox refused: stop trying
            let code = Self.hex(UInt32(bitPattern: status))
            Diagnostics.smc.error("Opening the SMC failed (\(code, privacy: .public)); its battery keys are not read")
        case .keyNotFound, .unreadable, .unsupportedSize:
            missing.insert(key)
            Diagnostics.smc.debug("\(name, privacy: .public) isn't readable on this Mac; not asked again")
        case .call(let status) where status == Self.notPrivileged:
            // macOS 27 refuses some keys to unprivileged clients; the rest keep working.
            missing.insert(key)
            Diagnostics.smc.debug("\(name, privacy: .public) needs privileges; not asked again")
        case .call(let status):
            logOnce(key, reason: "IOKit status \(Self.hex(UInt32(bitPattern: status)))")
        case .truncatedReply(let size):
            logOnce(key, reason: "a reply of \(size) bytes")
        case .smc(_, let result):
            logOnce(key, reason: "SMC result \(Self.hex(UInt32(result)))")
        }
    }

    /// A failure that may pass, such as a result of 0x85 while the SMC is busy around sleep: the key
    /// is asked for again on the next read, and logged once per session, or polls would repeat it.
    private func logOnce(_ key: SMCFourCC, reason: String) {
        guard loggedFailures.insert(key).inserted else { return }
        let name = key.description
        Diagnostics.smc.error("Reading \(name, privacy: .public) failed (\(reason, privacy: .public)); asked again")
    }

    /// `0xe00002c2`: IOKit statuses and SMC results read best in hex.
    private static func hex(_ value: UInt32) -> String {
        "0x" + String(value, radix: 16)
    }

    public func read(_ key: SMCFourCC) throws(Failure) -> SMCRawValue {
        let info = try self.info(for: key)
        guard info.isReadable else { throw .unreadable(key) }
        // Some keys hold up to 120 bytes; one call carries 32.
        guard info.size > 0, info.size <= UInt32(SMCParamBlock.payloadCapacity) else {
            throw .unsupportedSize(key, info.size)
        }
        let reply = try call(.readKey, key: key, dataSize: info.size)
        return SMCRawValue(key: key, info: info, payload: Array(reply.payload.prefix(Int(info.size))))
    }

    /// Type, size and attributes of a key. They don't change while macOS runs.
    public func info(for key: SMCFourCC) throws(Failure) -> SMCKeyInfo {
        if let cached = keyInfo[key] { return cached }
        let info = try call(.getKeyInfo, key: key).info
        keyInfo[key] = info
        return info
    }

    /// The number of keys, from `#KEY` (a big-endian `ui32` on Apple silicon too).
    public func keyCount() throws(Failure) -> Int {
        let value = try read("#KEY")
        return Int(SMCValueDecoder.number(value.payload, info: value.info, order: .big) ?? 0)
    }

    /// The key at a position in the SMC's key table.
    public func key(at index: Int) throws(Failure) -> SMCFourCC {
        try call(.getKeyFromIndex, index: UInt32(index)).key
    }

    // MARK: - Plumbing

    private func call(
        _ command: SMCParamBlock.Command, key: SMCFourCC = SMCFourCC(rawValue: 0), dataSize: UInt32 = 0,
        index: UInt32 = 0
    ) throws(Failure) -> SMCParamBlock.Reply {
        if port == 0 { port = try Self.openConnection() }
        let input = SMCParamBlock.request(command, key: key, dataSize: dataSize, index: index)
        var output = [UInt8](repeating: 0, count: SMCParamBlock.size)
        var outputSize = SMCParamBlock.size
        let connection = port
        let status = input.withUnsafeBytes { inBuffer in
            output.withUnsafeMutableBytes { outBuffer in
                IOConnectCallStructMethod(
                    connection, Self.selector, inBuffer.baseAddress, SMCParamBlock.size, outBuffer.baseAddress,
                    &outputSize)
            }
        }
        guard status == kIOReturnSuccess else {
            if Self.connectionLost.contains(status) {
                IOServiceClose(connection)
                port = 0
            }
            throw .call(status)
        }
        // A short reply would decode as zeros, and a zero result byte reads as success.
        guard outputSize == SMCParamBlock.size, let reply = SMCParamBlock.reply(from: output) else {
            throw .truncatedReply(outputSize)
        }
        switch reply.result {
        case SMCResult.success.rawValue: return reply
        case SMCResult.keyNotFound.rawValue: throw .keyNotFound(key)
        default: throw .smc(key, result: reply.result)
        }
    }

    /// Opens a connection of type 0 on the AppleSMC service, preferring the match named
    /// `AppleSMCKeysEndpoint` over whichever match comes first.
    private static func openConnection() throws(Failure) -> io_connect_t {
        var iterator: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMC"), &iterator) == KERN_SUCCESS
        else { throw .serviceNotFound }
        defer { IOObjectRelease(iterator) }

        var chosen: io_service_t = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if chosen == 0 || name(of: service) == "AppleSMCKeysEndpoint" {
                if chosen != 0 { IOObjectRelease(chosen) }
                chosen = service
                if name(of: service) == "AppleSMCKeysEndpoint" { break }
            } else {
                IOObjectRelease(service)
            }
            service = IOIteratorNext(iterator)
        }
        guard chosen != 0 else { throw .serviceNotFound }
        defer { IOObjectRelease(chosen) }

        var connection: io_connect_t = 0
        let status = IOServiceOpen(chosen, mach_task_self_, 0, &connection)
        guard status == KERN_SUCCESS, connection != 0 else { throw .open(status) }
        return connection
    }

    private static func name(of entry: io_registry_entry_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 128)  // io_name_t
        guard IORegistryEntryGetName(entry, &buffer) == KERN_SUCCESS else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
#endif
