// Swaps two paths in one atomic rename, as UpdateInstaller does when it replaces the app
// (`Updates/UpdateInstaller.swift`, `renamex_np` with `RENAME_SWAP`). The session script builds it
// once and calls it for every install:
//
//   xcrun swiftc -O docs/plans/0.7.0/swap.swift -o ~/bp-070/R/bin/swap
//   ~/bp-070/R/bin/swap <staged copy> /Applications/BatteryPulse.app
//
// Both paths must exist on the same volume. Exit status 0 on success, 1 with the reason on
// standard error otherwise, 2 for a wrong call.
import Darwin
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: swap <path> <path>\n".utf8))
    exit(2)
}
guard renamex_np(arguments[1], arguments[2], UInt32(RENAME_SWAP)) == 0 else {
    let reason = String(cString: strerror(errno))
    FileHandle.standardError.write(Data("swap: \(reason)\n".utf8))
    exit(1)
}
