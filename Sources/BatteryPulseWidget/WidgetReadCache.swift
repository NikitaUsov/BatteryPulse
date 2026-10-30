#if os(macOS)
import BatteryCore
import BatterySource
import Foundation
import Synchronization

/// One battery read per burst of timeline requests: WidgetKit asks for every placed widget's
/// timeline, and sometimes a snapshot beside it, in the same extension process at about the same
/// time, and every request within ``ReadCoalescer/window`` of a read shares it, whether it is still
/// running or done (``ReadCoalescer``, tested on Linux). A failed read, or one that found no
/// battery, is never kept, so the next request reads again.
final class WidgetReadCache: Sendable {
    /// The extension's one cache, which every Battery widget's provider shares.
    static let battery = WidgetReadCache()

    private let coalescer = Mutex(ReadCoalescer<BatterySnapshot, Task<BatterySnapshot?, Never>>())

    /// The battery as a read within the last few seconds found it, or as a new read finds it;
    /// `nil` without a battery.
    func snapshot() async -> BatterySnapshot? {
        let step = coalescer.withLock { coalescer in
            coalescer.request(at: .now) {
                Task(name: "WidgetReadCache.read") { await Self.read() }
            }
        }
        switch step {
        case .cached(let snapshot):
            return snapshot
        case .join(let read):
            return await read.value
        case .started(let read, let id):
            let snapshot = await read.value
            coalescer.withLock { $0.finish(id, with: snapshot) }
            return snapshot
        }
    }

    /// Reads IOKit directly, off the caller's thread: the sandboxed extension has no shared
    /// container with the app under ad-hoc signing. The SMC can't be opened from the sandbox, so
    /// it is skipped. A new provider for each read, which reads the registry in full and never
    /// reuses an earlier read's.
    @concurrent private static func read() async -> BatterySnapshot? {
        MacBatteryProvider(readsSMC: false).readNonisolated(scope: .full)?.snapshot
    }
}
#endif
