#if os(macOS)
import BatteryCore
import Foundation

/// Apple's private MobileDevice framework (the one Finder and Xcode use to talk to iPhones and
/// iPads), opened with `dlopen` on first use and never linked: a Mac without it, or a macOS that
/// drops a function, only loses device reading. Nothing loads it unless a device is asked for.
///
/// No entitlements are needed and the app isn't sandboxed. The framework is Apple-signed, so the
/// hardened runtime's library validation accepts it. A missing symbol is detected; a changed
/// signature is not, which is why every call goes through ``IDeviceLink`` and the bindings below
/// stay minimal. Return values are `mach_error_t` codes (``IDeviceStatus``).
struct MobileDeviceLibrary: @unchecked Sendable {
    // `@unchecked`: C function pointers are immutable addresses, safe to share between threads.

    /// The `AMDeviceNotificationSubscribe` callback: a pointer to
    /// `{AMDeviceRef device @0, UInt32 message @8, subscription @16}`, and the context pointer.
    typealias NotificationCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    /// `(callback, 0, 0, context, &subscription) -> status`.
    typealias Subscribe =
        @convention(c) (
            NotificationCallback, Int32, Int32, UnsafeMutableRawPointer?,
            UnsafeMutablePointer<UnsafeMutableRawPointer?>
        ) -> Int32
    /// Calls that take an `AMDeviceRef`, a subscription or a service connection and return a
    /// status, a socket, a flag or an interface type.
    typealias PointerCall = @convention(c) (UnsafeMutableRawPointer) -> Int32
    /// `AMDCreateDeviceList() -> CFArray` (+1).
    typealias CreateDeviceList = @convention(c) () -> Unmanaged<CFArray>?
    /// `AMDeviceCopyDeviceIdentifier(device) -> CFString` (+1), the UDID.
    typealias CopyIdentifier = @convention(c) (UnsafeMutableRawPointer) -> Unmanaged<CFString>?
    /// `AMDeviceCopyValue(device, domain, key) -> CFTypeRef` (+1).
    typealias CopyValue = @convention(c) (UnsafeMutableRawPointer, CFString?, CFString?) -> Unmanaged<CFTypeRef>?
    /// `AMDeviceSecureStartService(device, name, NULL, &connection) -> status`; the connection
    /// is +1.
    typealias SecureStartService =
        @convention(c) (
            UnsafeMutableRawPointer, CFString, CFDictionary?, UnsafeMutablePointer<UnsafeMutableRawPointer?>
        ) -> Int32
    /// `AMDServiceConnectionSendMessage(connection, plist, format) -> status`.
    typealias SendMessage = @convention(c) (UnsafeMutableRawPointer, CFTypeRef, CFPropertyListFormat) -> Int32
    /// `AMDServiceConnectionReceiveMessage(connection, &plist, &format) -> status`; the plist
    /// is +1.
    typealias ReceiveMessage =
        @convention(c) (
            UnsafeMutableRawPointer, UnsafeMutablePointer<Unmanaged<CFTypeRef>?>,
            UnsafeMutablePointer<CFPropertyListFormat>
        ) -> Int32
    /// `AMDServiceConnectionInvalidate(connection)`; the connection is released afterwards.
    typealias Invalidate = @convention(c) (UnsafeMutableRawPointer) -> Void

    /// Where macOS keeps the framework, then the older path (a symlink to it on current macOS).
    static let paths = [
        "/Library/Apple/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice",
        "/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice",
    ]

    let path: String
    let notificationSubscribe: Subscribe
    let notificationUnsubscribe: PointerCall
    /// Optional: notifications are the source of truth; the list is a second opinion.
    let createDeviceList: CreateDeviceList?
    let copyDeviceIdentifier: CopyIdentifier
    let getInterfaceType: PointerCall
    let connect: PointerCall
    let disconnect: PointerCall
    /// Optional: only informs the "not trusted" message.
    let isPaired: PointerCall?
    let validatePairing: PointerCall
    let startSession: PointerCall
    let stopSession: PointerCall
    let copyValue: CopyValue
    let secureStartService: SecureStartService
    let sendMessage: SendMessage
    let receiveMessage: ReceiveMessage
    let getSocket: PointerCall
    let invalidate: Invalidate

    /// Loaded at most once per process.
    static let shared: Result<MobileDeviceLibrary, IDeviceError> = load()

    private static func load() -> Result<MobileDeviceLibrary, IDeviceError> {
        var found: (handle: UnsafeMutableRawPointer, path: String)?
        var errors: [String] = []
        for path in paths {
            if let handle = dlopen(path, RTLD_NOW) {
                found = (handle, path)
                break
            }
            errors.append(dlerror().map { String(cString: $0) } ?? path)
        }
        guard let opened = found else { return .failure(.frameworkUnavailable(errors.joined(separator: "; "))) }

        var missing: [String] = []
        func symbol<T>(_ name: String, _ type: T.Type, required: Bool = true) -> T? {
            guard let pointer = dlsym(opened.handle, name) else {
                if required { missing.append(name) }
                return nil
            }
            return unsafeBitCast(pointer, to: type)
        }

        let subscribe = symbol("AMDeviceNotificationSubscribe", Subscribe.self)
        let unsubscribe = symbol("AMDeviceNotificationUnsubscribe", PointerCall.self)
        let createDeviceList = symbol("AMDCreateDeviceList", CreateDeviceList.self, required: false)
        let copyDeviceIdentifier = symbol("AMDeviceCopyDeviceIdentifier", CopyIdentifier.self)
        let getInterfaceType = symbol("AMDeviceGetInterfaceType", PointerCall.self)
        let connect = symbol("AMDeviceConnect", PointerCall.self)
        let disconnect = symbol("AMDeviceDisconnect", PointerCall.self)
        let isPaired = symbol("AMDeviceIsPaired", PointerCall.self, required: false)
        let validatePairing = symbol("AMDeviceValidatePairing", PointerCall.self)
        let startSession = symbol("AMDeviceStartSession", PointerCall.self)
        let stopSession = symbol("AMDeviceStopSession", PointerCall.self)
        let copyValue = symbol("AMDeviceCopyValue", CopyValue.self)
        let secureStartService = symbol("AMDeviceSecureStartService", SecureStartService.self)
        let sendMessage = symbol("AMDServiceConnectionSendMessage", SendMessage.self)
        let receiveMessage = symbol("AMDServiceConnectionReceiveMessage", ReceiveMessage.self)
        let getSocket = symbol("AMDServiceConnectionGetSocket", PointerCall.self)
        let invalidate = symbol("AMDServiceConnectionInvalidate", Invalidate.self)

        guard let subscribe, let unsubscribe, let copyDeviceIdentifier, let getInterfaceType, let connect,
            let disconnect, let validatePairing, let startSession, let stopSession, let copyValue,
            let secureStartService, let sendMessage, let receiveMessage, let getSocket, let invalidate
        else {
            dlclose(opened.handle)
            return .failure(.frameworkUnavailable("missing " + missing.joined(separator: ", ")))
        }
        return .success(
            MobileDeviceLibrary(
                path: opened.path,
                notificationSubscribe: subscribe,
                notificationUnsubscribe: unsubscribe,
                createDeviceList: createDeviceList,
                copyDeviceIdentifier: copyDeviceIdentifier,
                getInterfaceType: getInterfaceType,
                connect: connect,
                disconnect: disconnect,
                isPaired: isPaired,
                validatePairing: validatePairing,
                startSession: startSession,
                stopSession: stopSession,
                copyValue: copyValue,
                secureStartService: secureStartService,
                sendMessage: sendMessage,
                receiveMessage: receiveMessage,
                getSocket: getSocket,
                invalidate: invalidate
            ))
    }
}
#endif
