#if os(macOS)
import BatteryCore
import BatterySource
import Foundation
import Synchronization

/// One read per burst of timeline requests: WidgetKit asks for every placed widget's timeline,
/// and sometimes a snapshot beside it, in the same extension process at about the same time, and
/// every request within ``ReadCoalescer/window`` of a read shares it, whether it is still running
/// or done (``ReadCoalescer``, tested on Linux). A failed read is never kept, so the next request
/// reads again. Each kind has its own cache (``WidgetReads``).
final class WidgetReadCache<Value: Sendable>: Sendable {
    private let coalescer = Mutex(ReadCoalescer<Value, Task<Value?, Never>>())
    private let read: @Sendable () async -> Value?

    /// `read` returns `nil` for a read that failed.
    init(read: @escaping @Sendable () async -> Value?) {
        self.read = read
    }

    /// The value as a read within the last few seconds found it, or as a new read finds it; `nil`
    /// when the read failed.
    func value() async -> Value? {
        let read = self.read
        let step = coalescer.withLock { coalescer in
            coalescer.request(at: .now) {
                Task(name: "WidgetReadCache.read") { await read() }
            }
        }
        switch step {
        case .cached(let value):
            return value
        case .join(let task):
            return await task.value
        case .started(let task, let id):
            let value = await task.value
            coalescer.withLock { $0.finish(id, with: value) }
            return value
        }
    }
}

/// The extension's reads, one cache per kind, which every widget of the kind shares. The
/// sandboxed extension has no shared container with the app under ad-hoc signing, so it reads
/// for itself.
enum WidgetReads {
    /// The battery; `nil` without one, which is never kept.
    static let battery = WidgetReadCache<BatterySnapshot> { await readBattery() }

    /// The accessory batteries; `nil` when this macOS publishes none, which is never kept, and an
    /// empty list when none is connected, which is.
    static let accessories = WidgetReadCache<[AccessoryBattery]> { await readAccessories() }

    /// Reads IOKit directly, off the caller's thread. The SMC can't be opened from the sandbox, so
    /// it is skipped. A new provider for each read, which reads the registry in full and never
    /// reuses an earlier read's.
    @concurrent private static func readBattery() async -> BatterySnapshot? {
        MacBatteryProvider(readsSMC: false).readNonisolated(scope: .full)?.snapshot
    }

    /// One read of the power sources the accessories publish, on the main actor, where the
    /// provider lives: one hop per burst, from here. Only the one-shot read: the widget never
    /// observes the change notifications, which only the app's monitor registers.
    @concurrent private static func readAccessories() async -> [AccessoryBattery]? {
        await MainActor.run {
            Diagnostics.measure("accessory.read") { MacAccessoryProvider().read()?.accessories }
        }
    }
}
#endif
