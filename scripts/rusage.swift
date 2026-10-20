// Measures one process's energy, wake-ups, CPU time, instructions, disk writes and memory over a
// window, from the kernel's per-process counters (macOS, no root needed for your own processes).
//
//   swift scripts/rusage.swift <pid> <seconds>
//   swift scripts/rusage.swift "$(pgrep -x BatteryPulse)" 240
//
// It samples proc_pid_rusage(RUSAGE_INFO_V6) at the start and the end and prints the deltas
// scaled to one hour, one key=value per line:
//   energy_mj_per_h            ri_energy_nj, in millijoules
//   pcore_energy_pct           the P cores' share of it (ri_penergy_nj)
//   idle_wakeups_per_h         package-idle wake-ups (ri_pkg_idle_wkups)
//   interrupt_wakeups_per_h    ri_interrupt_wkups
//   cpu_s_per_h                user plus system time, in seconds
//   instructions_per_h         ri_instructions
//   disk_bytes_written_per_h   ri_diskio_byteswritten
//   phys_footprint_bytes       ri_phys_footprint at the end (not scaled)
// An energy figure of 0 usually means the kernel doesn't count it: check
// `sysctl kern.pervasive_energy`.
import Darwin
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

/// One sample of the process's counters.
func sample(_ pid: pid_t) -> rusage_info_v6 {
    var info = rusage_info_v6()
    // The kernel writes the whole structure at the address it is given, typed as rusage_info_t.
    let status = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { buffer in
            proc_pid_rusage(pid, RUSAGE_INFO_V6, buffer)
        }
    }
    guard status == 0 else {
        fail("proc_pid_rusage(\(pid)) failed: \(String(cString: strerror(errno)))")
    }
    return info
}

/// The growth of a counter between two samples; counters only grow while the process lives.
func delta(_ start: UInt64, _ end: UInt64) -> UInt64 {
    end >= start ? end - start : 0
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 2, let pid = pid_t(arguments[0]), pid > 0,
    let seconds = Double(arguments[1]), seconds > 0
else {
    fail("usage: swift scripts/rusage.swift <pid> <seconds>")
}

// CPU times are in Mach absolute-time units, not nanoseconds, on Apple silicon.
var timebase = mach_timebase_info_data_t()
guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom != 0 else {
    fail("mach_timebase_info failed")
}
let nanosecondsPerTick = Double(timebase.numer) / Double(timebase.denom)

let clock = ContinuousClock()
let first = sample(pid)
let startedAt = clock.now
Thread.sleep(forTimeInterval: seconds)
let last = sample(pid)
let elapsed = startedAt.duration(to: clock.now)
let elapsedSeconds =
    Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
let hours = elapsedSeconds / 3600

func perHour(_ value: Double) -> Double { value / hours }

/// A counter's growth over the window, per hour.
func counterPerHour(_ counter: KeyPath<rusage_info_v6, UInt64>) -> String {
    String(format: "%.0f", perHour(Double(delta(first[keyPath: counter], last[keyPath: counter]))))
}

let energy = delta(first.ri_energy_nj, last.ri_energy_nj)
let pCoreEnergy = delta(first.ri_penergy_nj, last.ri_penergy_nj)
let cpuTicks = delta(first.ri_user_time, last.ri_user_time) + delta(first.ri_system_time, last.ri_system_time)

let lines: [(String, String)] = [
    ("pid", "\(pid)"),
    ("seconds", String(format: "%.1f", elapsedSeconds)),
    ("energy_mj_per_h", String(format: "%.1f", perHour(Double(energy) / 1e6))),
    ("pcore_energy_pct", energy > 0 ? String(format: "%.1f", Double(pCoreEnergy) * 100 / Double(energy)) : "-"),
    ("idle_wakeups_per_h", counterPerHour(\.ri_pkg_idle_wkups)),
    ("interrupt_wakeups_per_h", counterPerHour(\.ri_interrupt_wkups)),
    ("cpu_s_per_h", String(format: "%.3f", perHour(Double(cpuTicks) * nanosecondsPerTick / 1e9))),
    ("instructions_per_h", counterPerHour(\.ri_instructions)),
    ("disk_bytes_written_per_h", counterPerHour(\.ri_diskio_byteswritten)),
    ("phys_footprint_bytes", "\(last.ri_phys_footprint)"),
]
for (key, value) in lines {
    print("\(key)=\(value)")
}
if energy == 0 {
    FileHandle.standardError.write(
        Data("note: ri_energy_nj didn't move; check `sysctl kern.pervasive_energy`\n".utf8))
}
