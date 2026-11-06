import BatteryCore
import Foundation

#if os(macOS)
import Darwin
#endif

/// The app and the Mac as a problem report names them (`ProblemReport.Identity`): the app's
/// version and build, the system's version string and the Mac's model identifier.
public enum SystemIdentity {
    /// The identity of the app in `bundle` on this Mac. The system's version string is
    /// `ProcessInfo`'s, such as "Version 27.1 (Build 27B48)": shown in the report, never parsed.
    public static func current(bundle: Bundle = .main) -> ProblemReport.Identity {
        ProblemReport.Identity(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            model: model())
    }

    /// The longest model identifier read; they are about ten bytes, such as "Mac17,3".
    static let maxModelBytes = 256

    /// The Mac's model identifier from `sysctlbyname("hw.model")`, as macOS writes it; `nil` where
    /// there is no such call (Linux, iOS) or it fails. Its form on the M5 is to be seen in a
    /// saved report.
    public static func model() -> String? {
        #if os(macOS)
        var size = 0
        // Unsafe: the name goes in as a C string and the value's size comes back through an
        // out-pointer; no value is read yet.
        guard unsafe sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0, size <= maxModelBytes else {
            return nil
        }
        var bytes = [UInt8](repeating: 0, count: size)
        // Unsafe: the value is written into `bytes`, which holds the `size` bytes the call is told
        // it may write, and its length comes back through an out-pointer.
        guard unsafe sysctlbyname("hw.model", &bytes, &size, nil, 0) == 0 else { return nil }
        let model = String(decoding: bytes.prefix(min(size, bytes.count)).prefix { $0 != 0 }, as: UTF8.self)
        return model.isEmpty ? nil : model
        #else
        return nil
        #endif
    }
}
