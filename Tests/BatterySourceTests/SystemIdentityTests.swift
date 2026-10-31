import BatteryCore
import Foundation
import Testing

@testable import BatterySource

@Suite struct SystemIdentityTests {
    @Test func theIdentityComesFromTheBundleAndTheSystem() {
        let identity = SystemIdentity.current(bundle: .main)
        #expect(
            identity.appVersion == Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        #expect(identity.build == Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        #expect(identity.systemVersion == ProcessInfo.processInfo.operatingSystemVersionString)
        #expect(identity.model == SystemIdentity.model())
    }

    /// CI's macOS is a virtual machine, so only the form is checked: one short line of text.
    @Test func theModelIsOneShortLine() throws {
        #if os(macOS)
        let model = try #require(SystemIdentity.model())
        #expect(!model.isEmpty && model.utf8.count < SystemIdentity.maxModelBytes)
        #expect(model.unicodeScalars.allSatisfy { $0.isASCII && $0.properties.generalCategory != .control })
        #expect(!model.contains(" "))
        #else
        #expect(SystemIdentity.model() == nil)
        #endif
    }
}
