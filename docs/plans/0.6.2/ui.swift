// The hands of the hands-free Session B (docs/plans/0.6.2/PLAN.md §6, WP-21): Accessibility (AX),
// posted mouse events (CGEvent) and the window list (CGWindowList), with safety rules of its own,
// so they don't rest on the Claude session alone. The session script builds it beside `frames` and
// is its only caller (`m5-session.sh ui <command>`):
//
//   xcrun swiftc -O docs/plans/0.6.2/ui.swift -o ~/bp-062/B/bin/ui
//
// A point is global display points, the top left of the main display at 0,0, given as `<x> <y>`,
// or as `--image <png> <x> <y>`: pixels of a full-screen shot of the main display (the script's
// `shot`), converted to points. Never computer use's scaled coordinates.
//
// Actions (each passes the safety rules below first):
//   click <point> [--shift | --control] [--double] [--cg-only]
//                                                    a left click; the modifier as flagsChanged;
//                                                    --cg-only hit-tests by the window list alone
//                                                    (the queue's: no AX call into BatteryPulse)
//   click --ax <app> <text> [--shift | --control]    at the centre of the element that matches
//   move <point> | move --here                       --here: a 0-pixel move (proof P6)
//   drag <point> <point> [--steps n] [--seconds s]   slow, in steps (the widget gallery)
//   scroll <point> <lines>                           positive lines scroll down
//   press <app> <text> [--role r] [--within role] [--index n] [--action AXPress]
//   press <app> --menu-cmd <char>                    the menu item with that Command key and no other
//                                                    modifier (Settings… is ",", Close "W")
//   select-row <app> <text>                          AXSelected on the matching row
//   minimize on|off <app> [--window <title>]         AXMinimized
//   fullscreen on|off <app> [--window <title>]       AXFullScreen (no keystroke)
//   position <app> <x> <y> [<width> <height>] [--window <title>]   (Terminal too: placed, never
//                                                    clicked)
//   banner <text> [--seconds n] [--probe]            finds the banner with that text (the
//                                                    notification's own body) in Notification
//                                                    Center's AX tree and presses it (--probe: only
//                                                    finds it)
//   quit <app>                                       an AX press on the app's own Quit menu item
// Reads:
//   frame <app> [--window <title> | --minimize-button | --match <text>] | frame --dock <title>
//   title <app>                                      its focused window's title (a System Settings pane)
//   hit <point>                                      the element there: process, role, label,
//                                                    the parent chain and the frame (proof P1)
//   tree <app> | --app <app> [--match <text>] [--inside x y w h] [--depth n]
//   windows [--app <name>] [--main [--allow-cover <app>]] [--status-item]
//   idle | locked | thermal | sample | access | screen | guard
//                                                    sample: idle, locked and thermal in one line
//   Options of every command: --tap hid|session (else BP_UI_TAP, else hid).
//
// Safety rules (exit status 3 when one refuses):
//   - no key presses at all: only a Shift or Control modifier, as a flagsChanged event, around a
//     click; never Esc, which would end the Claude session's turn;
//   - every click, move, drag and scroll hit-tests the point, by AX and by the topmost window
//     there, and acts only on an approved owner (BatteryPulse, the desktop, the Dock and the menu
//     bar, System Settings, Notification Center, the widget gallery's host, TextEdit,
//     Accessibility Inspector, Xcode; the hosts proof P1 found, from BP_UI_HOSTS);
//   - it always refuses SecurityAgent, UserNotificationCenter, CoreServicesUIAgent, coreautha,
//     loginwindow, a TCC prompt and Terminal, and System Settings while its pane is Privacy &
//     Security, Users & Groups, Passwords or Login Password;
//   - it refuses everything that touches AX or posts an event while the screen is locked or the
//     lid is closed, and while ~/bp-062/B/queue.started (or BP_FENCE) exists, unless the process
//     named in that file (the arm window's queue) is among its own ancestors;
//   - it refuses any point within 20 points of a hot corner set to Start Screen Saver, Put Display
//     to Sleep or Lock Screen;
//   - `guard` exits 3 when any of these holds now, or a refused process shows a window.
// Exit status: 0 done, 1 failed, 2 a wrong call, 3 refused, 4 not found.
//
// Privacy: window and element labels are printed only for BatteryPulse and Apple's own processes
// ("another app" otherwise); `tree` of another app prints only what --match or --inside selects,
// and of System Settings only whether the match exists. Every call is public API.
import ApplicationServices
import CoreGraphics
import Foundation
import IOKit
import ImageIO

struct Refusal: Error, CustomStringConvertible { let description: String }
struct Failure: Error, CustomStringConvertible { let description: String }
struct UsageError: Error, CustomStringConvertible { let description: String }
struct NotFound: Error, CustomStringConvertible { let description: String }

/// A running process: its ID, its name (`proc_name`) and its bundle identifier, if any.
struct RunningProcess {
    let pid: pid_t
    let name: String
    let bundle: String

    /// Whether its name may be printed: Apple's own processes and BatteryPulse.
    var isPublic: Bool { bundle.hasPrefix("com.apple.") || bundle.hasPrefix(Rules.batteryPulse) }

    var publicName: String { isPublic ? name : "another app" }
}

/// One on-screen window of `CGWindowListCopyWindowInfo`, front to back.
struct Window {
    let id: UInt32
    let pid: pid_t
    let owner: String
    let name: String
    let layer: Int
    let bounds: CGRect
    let alpha: Double
}

enum Rules {
    static let batteryPulse = "io.github.nikitausov.BatteryPulse"
    /// The owners a click may land on, by bundle identifier.
    static let approvedBundles: Set<String> = [
        batteryPulse, "com.apple.finder", "com.apple.dock", "com.apple.WindowManager",
        "com.apple.wallpaper.agent", "com.apple.systemuiserver", "com.apple.controlcenter",
        "com.apple.systempreferences", "com.apple.notificationcenterui", "com.apple.TextEdit",
        "com.apple.AccessibilityInspector", "com.apple.dt.Xcode", "com.apple.chronod",
    ]
    /// The desktop picture's owner, whatever macOS 27 calls it.
    static let approvedPrefixes = ["com.apple.wallpaper"]
    /// The window server's own windows (the menu bar, the cursor), by owner name.
    static let approvedOwners: Set<String> = ["Window Server", "WindowServer"]
    /// Never acted on, whatever the approved list says.
    static let refusedNames: Set<String> = [
        "SecurityAgent", "UserNotificationCenter", "CoreServicesUIAgent", "coreautha", "loginwindow",
        "universalAccessAuthWarn", "tccd", "Terminal", "SystemUIServer-TCC",
    ]
    static let refusedBundles: Set<String> = [
        "com.apple.SecurityAgent", "com.apple.UserNotificationCenter", "com.apple.coreservices.uiagent",
        "com.apple.loginwindow", "com.apple.Terminal", "com.apple.LocalAuthentication.UIAgent",
        "com.apple.tccd", "com.apple.accessibility.universalAccessAuthWarn",
    ]
    /// System Settings panes it never acts in, English and Russian, lowercased, as window title
    /// fragments ("password" covers Passwords, Login Password and Touch ID & Password).
    static let refusedPanes: [String] = [
        "privacy", "users & groups", "password",
        "\u{043A}\u{043E}\u{043D}\u{0444}\u{0438}\u{0434}\u{0435}\u{043D}\u{0446}\u{0438}\u{0430}\u{043B}\u{044C}\u{043D}\u{043E}\u{0441}\u{0442}\u{044C}",
        "\u{043F}\u{043E}\u{043B}\u{044C}\u{0437}\u{043E}\u{0432}\u{0430}\u{0442}\u{0435}\u{043B}\u{0438} \u{0438} \u{0433}\u{0440}\u{0443}\u{043F}\u{043F}\u{044B}",
        "\u{043F}\u{0430}\u{0440}\u{043E}\u{043B}",
    ]
    /// Hot corner actions it keeps away from: Start Screen Saver, Put Display to Sleep, Lock Screen.
    static let dangerousCorners: Set<Int> = [5, 10, 13]
    static let cornerMargin: CGFloat = 20
    /// Apps known by another name than their process.
    static let aliases: [String: String] = [
        "notification center": "com.apple.notificationcenterui", "notificationcenter": "com.apple.notificationcenterui",
        "system settings": "com.apple.systempreferences", "dock": "com.apple.dock", "finder": "com.apple.finder",
        "batterypulse": batteryPulse, "textedit": "com.apple.TextEdit", "xcode": "com.apple.dt.Xcode",
        "accessibility inspector": "com.apple.AccessibilityInspector",
    ]

    static func isRefused(_ process: RunningProcess) -> Bool {
        refusedNames.contains(process.name) || refusedBundles.contains(process.bundle)
            || process.name.localizedCaseInsensitiveContains("tcc")
    }

    static func isApproved(_ process: RunningProcess) -> Bool {
        if isRefused(process) { return false }
        if approvedBundles.contains(process.bundle) || approvedOwners.contains(process.name) { return true }
        if approvedPrefixes.contains(where: { process.bundle.hasPrefix($0) }) { return true }
        // The widget hosts proof P1 found, which the script passes on.
        let hosts = (ProcessInfo.processInfo.environment["BP_UI_HOSTS"] ?? "").split(separator: " ").map(String.init)
        return hosts.contains(process.bundle) || hosts.contains(process.name)
    }
}

// MARK: - Processes

enum Processes {
    static func name(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return "pid \(pid)" }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    static func path(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// The identifier of the bundle the executable sits in (an app, an extension or a bundle).
    static func bundle(ofExecutable path: String) -> String {
        var url = URL(fileURLWithPath: path)
        while url.path != "/" {
            url = url.deletingLastPathComponent()
            if ["app", "appex", "bundle", "xpc"].contains(url.pathExtension) {
                return Bundle(url: url)?.bundleIdentifier ?? ""
            }
        }
        return ""
    }

    static func process(_ pid: pid_t) -> RunningProcess {
        RunningProcess(pid: pid, name: name(pid), bundle: path(pid).map(bundle(ofExecutable:)) ?? "")
    }

    static func all() -> [pid_t] {
        var pids = [pid_t](repeating: 0, count: 8192)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        guard count > 0 else { return [] }
        return pids.prefix(Int(count)).filter { $0 > 0 }
    }

    /// The running app a name, alias or bundle identifier stands for.
    static func app(_ query: String) throws -> RunningProcess {
        let wanted = Rules.aliases[query.lowercased()] ?? query
        var byName: RunningProcess?
        for pid in all() {
            guard let path = path(pid), path.contains(".app/") else { continue }
            let bundle = bundle(ofExecutable: path)
            if bundle == wanted { return RunningProcess(pid: pid, name: name(pid), bundle: bundle) }
            if byName == nil, name(pid) == wanted || URL(fileURLWithPath: path).lastPathComponent == wanted {
                byName = RunningProcess(pid: pid, name: name(pid), bundle: bundle)
            }
        }
        if let byName { return byName }
        throw NotFound(description: "\(query) isn't running")
    }

    static func parent(_ pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return pid_t(info.pbi_ppid)
    }

    static func ancestors() -> [pid_t] {
        var chain: [pid_t] = []
        var pid = getppid()
        while pid > 1, chain.count < 64 {
            chain.append(pid)
            guard let next = parent(pid), next != pid else { break }
            pid = next
        }
        return chain
    }
}

// MARK: - Accessibility

enum AX {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    static func elements(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
        guard let value = attribute(element, name) else { return [] }
        return (value as? [AnyObject] ?? []).compactMap { Self.element($0) }
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] { elements(element, "AXChildren") }

    static func actions(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success, let names = names as? [String] else {
            return []
        }
        return names
    }

    static func application(_ process: RunningProcess) -> AXUIElement {
        let element = AXUIElementCreateApplication(process.pid)
        _ = AXUIElementSetMessagingTimeout(element, 3)
        return element
    }

    static func pid(_ element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return pid
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, "AXPosition"), let size = attribute(element, "AXSize"),
            CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &point),
            AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &extent)
        else { return nil }
        return CGRect(origin: point, size: extent)
    }

    /// Title, description, value (if text), identifier and help, the parts a match looks at.
    static func label(_ element: AXUIElement) -> String {
        ["AXTitle", "AXDescription", "AXValue", "AXIdentifier", "AXHelp"]
            .compactMap { string(element, $0) }.filter { !$0.isEmpty }.joined(separator: " | ")
    }

    /// AXValue as text, numbers included (a checkbox's 0 or 1).
    static func value(_ element: AXUIElement) -> String {
        guard let value = attribute(element, "AXValue") else { return "-" }
        if let number = value as? NSNumber { return number.stringValue }
        if let text = value as? String { return text.count > 60 ? String(text.prefix(60)) + "…" : text }
        return "-"
    }

    static func role(_ element: AXUIElement) -> String {
        let role = string(element, "AXRole") ?? "?"
        if let subrole = string(element, "AXSubrole"), !subrole.isEmpty { return "\(role)/\(subrole)" }
        return role
    }

    /// Breadth first, at most `depth` levels and 20,000 elements.
    static func find(in root: AXUIElement, text: String?, role wanted: String?, depth: Int) -> [AXUIElement] {
        var found: [AXUIElement] = []
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var index = 0
        while index < queue.count, queue.count < 20_000 {
            let (element, level) = queue[index]
            index += 1
            let roleMatches = wanted.map { role(element).hasPrefix($0) } ?? true
            let textMatches = text.map { label(element).localizedCaseInsensitiveContains($0) } ?? true
            if roleMatches, textMatches, index > 1 { found.append(element) }
            if level < depth {
                for child in children(element) { queue.append((child, level + 1)) }
            }
        }
        return found
    }

    static func windows(_ process: RunningProcess) -> [AXUIElement] { elements(application(process), "AXWindows") }

    /// The window titled `title`, else the main window, else the first one.
    static func window(_ process: RunningProcess, title: String?) throws -> AXUIElement {
        let all = windows(process)
        if let title {
            if let match = all.first(where: { (string($0, "AXTitle") ?? "").localizedCaseInsensitiveContains(title) }) {
                return match
            }
            throw NotFound(description: "no window titled \(title) in \(process.publicName)")
        }
        if let main = element(attribute(application(process), "AXMainWindow")) { return main }
        if let first = all.first { return first }
        throw NotFound(description: "\(process.publicName) has no window")
    }

    static func set(_ element: AXUIElement, _ name: String, _ value: CFTypeRef) throws {
        let error = AXUIElementSetAttributeValue(element, name as CFString, value)
        guard error == .success else {
            throw Failure(description: "setting \(name) failed (AXError \(error.rawValue))")
        }
    }

    static func perform(_ element: AXUIElement, _ action: String) throws {
        let error = AXUIElementPerformAction(element, action as CFString)
        guard error == .success else { throw Failure(description: "\(action) failed (AXError \(error.rawValue))") }
    }
}

// MARK: - The screen, the window list, the session

enum Screen {
    /// Every active display's bounds, in global points.
    static func displays() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return [CGDisplayBounds(CGMainDisplayID())]
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else {
            return [CGDisplayBounds(CGMainDisplayID())]
        }
        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }

    /// The main display's pixels per point.
    static func scale() -> CGFloat {
        guard let mode = CGDisplayCopyDisplayMode(CGMainDisplayID()), mode.width > 0 else { return 1 }
        return CGFloat(mode.pixelWidth) / CGFloat(mode.width)
    }

    static func windows() -> [Window] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return list.compactMap { info in
            guard let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
            else { return nil }
            return Window(
                id: id, pid: pid, owner: info[kCGWindowOwnerName as String] as? String ?? "",
                name: info[kCGWindowName as String] as? String ?? "",
                layer: (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0, bounds: bounds,
                alpha: (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1)
        }
    }

    /// The frontmost visible window that contains the point.
    static func topWindow(at point: CGPoint) -> Window? {
        windows().first { $0.bounds.contains(point) && $0.alpha > 0.01 && $0.layer < 1000 }
    }

    static func session() -> [String: Any] {
        (CGSessionCopyCurrentDictionary() as? [String: Any]) ?? [:]
    }

    static func isLocked() -> Bool { (session()["CGSSessionScreenIsLocked"] as? Bool) ?? false }

    static func isOnConsole() -> Bool { (session()["kCGSSessionOnConsoleKey"] as? Bool) ?? true }

    static func registryProperty(_ service: String, _ key: String) -> CFTypeRef? {
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(service))
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        return IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    static func isLidClosed() -> Bool { (registryProperty("IOPMrootDomain", "AppleClamshellState") as? Bool) ?? false }

    /// HIDIdleTime, the seconds since the last HID event, as `ioreg -c IOHIDSystem` shows it.
    static func hidIdleSeconds() -> Double? {
        guard let value = registryProperty("IOHIDSystem", "HIDIdleTime") else { return nil }
        if let number = value as? NSNumber { return number.doubleValue / 1e9 }
        if let data = value as? Data, data.count >= 8 {
            let nanoseconds = data.prefix(8).enumerated().reduce(UInt64(0)) {
                $0 | UInt64($1.element) << (8 * UInt64($1.offset))
            }
            return Double(nanoseconds) / 1e9
        }
        return nil
    }

    static func secondsSinceInput(_ state: CGEventSourceStateID) -> Double {
        // kCGAnyInputEventType, a macro Swift doesn't import: every event type.
        guard let any = CGEventType(rawValue: ~0) else { return -1 }
        return CGEventSource.secondsSinceLastEventType(state, eventType: any)
    }

    /// The hot corners' actions (com.apple.dock wvous-*-corner).
    static func corners() -> [(name: String, action: Int)] {
        ["tl", "tr", "bl", "br"].map { corner in
            let value = CFPreferencesCopyAppValue("wvous-\(corner)-corner" as CFString, "com.apple.dock" as CFString)
            return (corner, (value as? NSNumber)?.intValue ?? 0)
        }
    }
}

// MARK: - The safety rules

enum Safety {
    static func fenceFiles() -> [String] {
        var files = [NSHomeDirectory() + "/bp-062/B/queue.started"]
        if let extra = ProcessInfo.processInfo.environment["BP_FENCE"], !extra.isEmpty { files.append(extra) }
        return files
    }

    /// Refuses while the queue runs, unless the queue's own process is an ancestor.
    static func checkFence() throws {
        for file in fenceFiles() where FileManager.default.fileExists(atPath: file) {
            let text = (try? String(contentsOfFile: file, encoding: .utf8)) ?? ""
            let owner = text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).first.flatMap {
                pid_t($0)
            }
            if let owner, Processes.ancestors().contains(owner) { continue }
            throw Refusal(description: "the energy queue runs (\(file) exists): nothing may act until the morning")
        }
    }

    static func checkSession() throws {
        if Screen.isLocked() { throw Refusal(description: "the screen is locked") }
        if Screen.isLidClosed() { throw Refusal(description: "the lid is closed") }
        if !Screen.isOnConsole() { throw Refusal(description: "the session isn't on the console") }
    }

    /// Every rule that doesn't depend on a point.
    static func checkAll() throws {
        try checkFence()
        try checkSession()
    }

    static func checkCorners(_ point: CGPoint) throws {
        let dangerous = Screen.corners().filter { Rules.dangerousCorners.contains($0.action) }
        guard !dangerous.isEmpty else { return }
        for display in Screen.displays() {
            let spots: [String: CGPoint] = [
                "tl": CGPoint(x: display.minX, y: display.minY), "tr": CGPoint(x: display.maxX, y: display.minY),
                "bl": CGPoint(x: display.minX, y: display.maxY), "br": CGPoint(x: display.maxX, y: display.maxY),
            ]
            for corner in dangerous {
                guard let spot = spots[corner.name] else { continue }
                if abs(point.x - spot.x) <= Rules.cornerMargin, abs(point.y - spot.y) <= Rules.cornerMargin {
                    throw Refusal(
                        description:
                            "(\(Int(point.x)), \(Int(point.y))) is within 20 points of a hot corner (\(corner.name), action \(corner.action))"
                    )
                }
            }
        }
    }

    /// The System Settings window title, if System Settings shows a window.
    static func settingsTitle() -> String? {
        guard let settings = try? Processes.app("com.apple.systempreferences") else { return nil }
        let app = AX.application(settings)
        let window = AX.element(AX.attribute(app, "AXFocusedWindow")) ?? AX.element(AX.attribute(app, "AXMainWindow"))
        return window.flatMap { AX.string($0, "AXTitle") }
    }

    static func checkSettingsPane() throws {
        guard let title = settingsTitle()?.lowercased() else { return }
        if Rules.refusedPanes.contains(where: { title.contains($0) }) {
            throw Refusal(description: "System Settings shows a pane it never acts in")
        }
    }

    /// The owner of what lies at the point, by AX and by the topmost window, must be approved.
    /// With `byAX` false (the queue's --cg-only), only the window list hit-tests the point: an AX hit
    /// test asks the app under the point, and the measured process must never have an AX client.
    static func checkPoint(_ point: CGPoint, byAX: Bool = true) throws {
        try checkCorners(point)
        var owners: [RunningProcess] = []
        var element: AXUIElement?
        if byAX,
            AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element)
                == .success, let element, let pid = AX.pid(element)
        {
            owners.append(Processes.process(pid))
        }
        if let window = Screen.topWindow(at: point) { owners.append(Processes.process(window.pid)) }
        guard !owners.isEmpty else {
            throw Refusal(description: "nothing to hit-test at (\(Int(point.x)), \(Int(point.y)))")
        }
        for owner in owners {
            if Rules.isRefused(owner) { throw Refusal(description: "\(owner.publicName) is at that point: never acted on") }
            if !Rules.isApproved(owner) {
                throw Refusal(description: "\(owner.publicName) is at that point: not on the approved list")
            }
            if owner.bundle == "com.apple.systempreferences" { try checkSettingsPane() }
        }
    }

    /// An app an AX action may target.
    static func checkTarget(_ process: RunningProcess) throws {
        if Rules.isRefused(process) { throw Refusal(description: "\(process.publicName) is never acted on") }
        if !Rules.isApproved(process) { throw Refusal(description: "\(process.publicName) isn't on the approved list") }
        if process.bundle == "com.apple.systempreferences" { try checkSettingsPane() }
    }

    /// `guard`: every rule, now, plus no refused process showing a window.
    static func checkNow() throws {
        try checkAll()
        for window in Screen.windows() where window.alpha > 0.01 && window.bounds.width * window.bounds.height > 100 {
            let owner = Processes.process(window.pid)
            if owner.name == "Terminal" { continue }
            if Rules.isRefused(owner) {
                throw Refusal(description: "\(owner.publicName) shows a window (a dialog or a prompt)")
            }
        }
        if let front = Screen.windows().first(where: { $0.layer == 0 && $0.alpha > 0.01 }),
            Processes.process(front.pid).bundle == "com.apple.systempreferences"
        {
            try checkSettingsPane()
        }
    }
}

// MARK: - Posted events

enum Events {
    static func tap(_ options: Options) -> CGEventTapLocation {
        let name = options.value("--tap") ?? ProcessInfo.processInfo.environment["BP_UI_TAP"] ?? "hid"
        return name == "session" ? .cgSessionEventTap : .cghidEventTap
    }

    static func source() -> CGEventSource? { CGEventSource(stateID: .combinedSessionState) }

    static func pause(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

    static func mouse(_ type: CGEventType, _ point: CGPoint, flags: CGEventFlags, clicks: Int, tap: CGEventTapLocation)
        throws
    {
        guard
            let event = CGEvent(
                mouseEventSource: source(), mouseType: type, mouseCursorPosition: point, mouseButton: .left)
        else { throw Failure(description: "can't make a mouse event") }
        if clicks > 0 { event.setIntegerValueField(.mouseEventClickState, value: Int64(clicks)) }
        event.flags = flags
        event.post(tap: tap)
    }

    /// A modifier's flagsChanged event, the way the key reports itself: never a key press.
    static func modifier(_ flags: CGEventFlags, down: Bool, tap: CGEventTapLocation) throws {
        // kVK_Shift is 56, kVK_Control 59 (HIToolbox's Events.h).
        let key: CGKeyCode = flags.contains(.maskControl) ? 59 : 56
        guard let event = CGEvent(keyboardEventSource: source(), virtualKey: key, keyDown: down) else {
            throw Failure(description: "can't make a modifier event")
        }
        event.type = .flagsChanged
        event.flags = down ? flags : []
        event.post(tap: tap)
    }

    static func click(_ point: CGPoint, modifier flags: CGEventFlags, double: Bool, tap: CGEventTapLocation) throws {
        if !flags.isEmpty {
            try modifier(flags, down: true, tap: tap)
            pause(0.08)
        }
        try mouse(.mouseMoved, point, flags: flags, clicks: 0, tap: tap)
        pause(0.08)
        for count in 1...(double ? 2 : 1) {
            try mouse(.leftMouseDown, point, flags: flags, clicks: count, tap: tap)
            pause(0.05)
            try mouse(.leftMouseUp, point, flags: flags, clicks: count, tap: tap)
            pause(0.08)
        }
        if !flags.isEmpty {
            pause(0.08)
            try modifier(flags, down: false, tap: tap)
        }
    }

    static func current() -> CGPoint { CGEvent(source: nil)?.location ?? .zero }
}

// MARK: - Arguments

struct Options {
    var words: [String] = []
    var flags: Set<String> = []
    var values: [String: String] = [:]
    var lists: [String: [String]] = [:]

    /// Pulls the options out; what stays in `words` are the positional arguments.
    init(_ arguments: [String]) throws {
        let takesOne: Set<String> = [
            "--tap", "--window", "--match", "--role", "--index", "--action", "--menu-cmd", "--steps", "--seconds",
            "--depth", "--app", "--allow-cover", "--dock", "--ax", "--within",
        ]
        let takesFour: Set<String> = ["--inside"]
        let switches: Set<String> = [
            "--shift", "--control", "--double", "--here", "--probe", "--main", "--minimize-button", "--status-item",
            "--cg-only",
        ]
        var rest: [String] = []
        var index = 0
        while index < arguments.count {
            let word = arguments[index]
            if switches.contains(word) {
                flags.insert(word)
                index += 1
            } else if takesOne.contains(word) {
                guard index + 1 < arguments.count else { throw UsageError(description: "\(word) takes a value") }
                values[word] = arguments[index + 1]
                index += 2
            } else if takesFour.contains(word) {
                guard index + 4 < arguments.count else {
                    throw UsageError(description: "\(word) takes x y width height")
                }
                lists[word] = Array(arguments[(index + 1)...(index + 4)])
                index += 5
            } else if word == "--image" {
                guard index + 3 < arguments.count else { throw UsageError(description: "--image takes <png> <x> <y>") }
                let point = try Options.imagePoint(arguments[index + 1], arguments[index + 2], arguments[index + 3])
                rest.append(contentsOf: [String(Double(point.x)), String(Double(point.y))])
                index += 4
            } else {
                rest.append(word)
                index += 1
            }
        }
        words = rest
    }

    func has(_ flag: String) -> Bool { flags.contains(flag) }

    func value(_ name: String) -> String? { values[name] }

    func number(_ name: String, default fallback: Double) throws -> Double {
        guard let text = values[name] else { return fallback }
        guard let number = Double(text) else { throw UsageError(description: "\(name) takes a number") }
        return number
    }

    func rect(_ name: String) throws -> CGRect? {
        guard let list = lists[name] else { return nil }
        let numbers = list.compactMap(Double.init)
        guard numbers.count == 4 else { throw UsageError(description: "\(name) takes four numbers") }
        return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }

    /// Pixels of a full-screen shot of the main display, as points.
    static func imagePoint(_ path: String, _ x: String, _ y: String) throws -> CGPoint {
        guard let px = Double(x), let py = Double(y) else {
            throw UsageError(description: "--image takes pixel numbers")
        }
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
            let width = (properties[kCGImagePropertyPixelWidth as String] as? NSNumber)?.doubleValue,
            let height = (properties[kCGImagePropertyPixelHeight as String] as? NSNumber)?.doubleValue
        else { throw Failure(description: "can't read \(path)") }
        let display = CGDisplayBounds(CGMainDisplayID())
        let scale = width / Double(display.width)
        guard scale > 0, abs(height / scale - Double(display.height)) < 2 else {
            throw UsageError(
                description: "\(path) isn't a full-screen shot of the main display (\(Int(width))×\(Int(height)))")
        }
        return CGPoint(x: Double(display.minX) + px / scale, y: Double(display.minY) + py / scale)
    }

    /// A point from the next two positional words.
    func point(at index: Int) throws -> CGPoint {
        guard index + 1 < words.count, let x = Double(words[index]), let y = Double(words[index + 1]) else {
            throw UsageError(description: "a point is <x> <y> or --image <png> <x> <y>")
        }
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Commands

enum Command {
    static func describe(_ rect: CGRect) -> String {
        "\(Int(rect.minX.rounded())) \(Int(rect.minY.rounded())) \(Int(rect.width.rounded())) \(Int(rect.height.rounded()))"
    }

    static func modifier(_ options: Options) throws -> CGEventFlags {
        if options.has("--shift"), options.has("--control") { throw UsageError(description: "one modifier at most") }
        if options.has("--shift") { return .maskShift }
        if options.has("--control") { return .maskControl }
        return []
    }

    static func appArgument(_ options: Options, _ index: Int) throws -> RunningProcess {
        guard index < options.words.count else { throw UsageError(description: "name the app") }
        return try Processes.app(options.words[index])
    }

    /// The app of a read: `--app <name>` (the plan's spelling) or the first word.
    static func readTarget(_ options: Options) throws -> RunningProcess {
        if let name = options.value("--app") { return try Processes.app(name) }
        return try appArgument(options, 1)
    }

    /// The element of `app` that `text` matches, the `--index`th (from 1).
    static func match(_ process: RunningProcess, _ text: String, _ options: Options) throws -> AXUIElement {
        let depth = Int(try options.number("--depth", default: 40))
        var root = AX.application(process)
        if let container = options.value("--within") {
            // The first element of that role (a sidebar's AXOutline, say), so a page's name in the
            // window's title doesn't match too.
            guard let first = AX.find(in: root, text: nil, role: container, depth: depth).first else {
                throw NotFound(description: "no \(container) in \(process.publicName)")
            }
            root = first
        }
        let found = AX.find(in: root, text: text, role: options.value("--role"), depth: depth)
        let index = Int(try options.number("--index", default: 1))
        guard index >= 1, index <= found.count else {
            throw NotFound(description: "no element matching \(text) in \(process.publicName) (\(found.count) found)")
        }
        return found[index - 1]
    }

    static func click(_ options: Options) throws {
        try Safety.checkAll()
        let point: CGPoint
        if let appName = options.value("--ax") {
            let process = try Processes.app(appName)
            try Safety.checkTarget(process)
            guard let text = options.words.dropFirst().first else {
                throw UsageError(description: "click --ax <app> <text>")
            }
            let element = try match(process, text, options)
            guard let frame = AX.frame(element) else { throw Failure(description: "the element has no frame") }
            point = CGPoint(x: frame.midX, y: frame.midY)
        } else {
            point = try options.point(at: 1)
        }
        try Safety.checkPoint(point, byAX: !options.has("--cg-only"))
        try Events.click(
            point, modifier: try modifier(options), double: options.has("--double"), tap: Events.tap(options))
        print("clicked \(Int(point.x)) \(Int(point.y))")
    }

    static func move(_ options: Options) throws {
        try Safety.checkAll()
        let point = options.has("--here") ? Events.current() : try options.point(at: 1)
        // A 0-pixel move where the pointer already is clicks nothing: no hit test, so it works over
        // Terminal too (proof P6).
        if !options.has("--here") { try Safety.checkPoint(point) }
        try Events.mouse(.mouseMoved, point, flags: [], clicks: 0, tap: Events.tap(options))
        print("moved to \(Int(point.x)) \(Int(point.y))")
    }

    static func drag(_ options: Options) throws {
        try Safety.checkAll()
        let from = try options.point(at: 1)
        let to = try options.point(at: 3)
        let steps = max(2, Int(try options.number("--steps", default: 30)))
        let seconds = max(0.2, try options.number("--seconds", default: 2))
        let points = (0...steps).map { step -> CGPoint in
            let t = CGFloat(step) / CGFloat(steps)
            return CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        }
        for point in points { try Safety.checkCorners(point) }
        try Safety.checkPoint(from)
        try Safety.checkPoint(to)
        let tap = Events.tap(options)
        try Events.mouse(.mouseMoved, from, flags: [], clicks: 0, tap: tap)
        Events.pause(0.1)
        try Events.mouse(.leftMouseDown, from, flags: [], clicks: 1, tap: tap)
        // A hold before the first step, so a widget in the gallery lifts.
        Events.pause(0.4)
        for point in points.dropFirst() {
            try Events.mouse(.leftMouseDragged, point, flags: [], clicks: 1, tap: tap)
            Events.pause(seconds / Double(steps))
        }
        Events.pause(0.3)
        try Events.mouse(.leftMouseUp, to, flags: [], clicks: 1, tap: tap)
        print("dragged \(Int(from.x)) \(Int(from.y)) to \(Int(to.x)) \(Int(to.y)) in \(steps) steps")
    }

    static func scroll(_ options: Options) throws {
        try Safety.checkAll()
        let point = try options.point(at: 1)
        guard options.words.count > 3, let lines = Int32(options.words[3]) else {
            throw UsageError(description: "scroll <point> <lines>")
        }
        try Safety.checkPoint(point)
        let tap = Events.tap(options)
        try Events.mouse(.mouseMoved, point, flags: [], clicks: 0, tap: tap)
        Events.pause(0.08)
        // A wheel's positive value scrolls content down the screen; positive lines here go down the page.
        guard
            let event = CGEvent(
                scrollWheelEvent2Source: Events.source(), units: .line, wheelCount: 1, wheel1: -lines, wheel2: 0,
                wheel3: 0)
        else { throw Failure(description: "can't make a scroll event") }
        event.location = point
        event.post(tap: tap)
        print("scrolled \(lines) lines at \(Int(point.x)) \(Int(point.y))")
    }

    static func press(_ options: Options) throws {
        try Safety.checkAll()
        let process = try appArgument(options, 1)
        try Safety.checkTarget(process)
        if let character = options.value("--menu-cmd") {
            let item = try menuItem(process, command: character)
            try AX.perform(item, "AXPress")
            print("pressed the menu item with Command-\(character) in \(process.publicName)")
            return
        }
        guard options.words.count > 2 else { throw UsageError(description: "press <app> <text>") }
        var element = try match(process, options.words[2], options)
        let action = options.value("--action") ?? "AXPress"
        // A label inside a button: press the nearest ancestor that can.
        var hops = 0
        while !AX.actions(element).contains(action), hops < 4,
            let parent = AX.element(AX.attribute(element, "AXParent"))
        {
            element = parent
            hops += 1
        }
        try AX.perform(element, action)
        print("\(action) on \(AX.role(element)) in \(process.publicName)")
    }

    /// A menu bar item by its Command-key equivalent, with no other modifier (so the same in every
    /// language).
    static func menuItem(_ process: RunningProcess, command character: String) throws -> AXUIElement {
        guard let bar = AX.element(AX.attribute(AX.application(process), "AXMenuBar")) else {
            throw NotFound(description: "\(process.publicName) has no menu bar")
        }
        for item in AX.find(in: bar, text: nil, role: "AXMenuItem", depth: 6) {
            let key = AX.string(item, "AXMenuItemCmdChar") ?? ""
            let modifiers = (AX.attribute(item, "AXMenuItemCmdModifiers") as? NSNumber)?.intValue ?? -1
            if key.caseInsensitiveCompare(character) == .orderedSame, modifiers == 0 { return item }
        }
        throw NotFound(description: "no Command-\(character) menu item in \(process.publicName)")
    }

    static func selectRow(_ options: Options) throws {
        try Safety.checkAll()
        let process = try appArgument(options, 1)
        try Safety.checkTarget(process)
        guard options.words.count > 2 else { throw UsageError(description: "select-row <app> <text>") }
        var element = try match(process, options.words[2], options)
        var hops = 0
        while !AX.role(element).hasPrefix("AXRow"), hops < 5, let parent = AX.element(AX.attribute(element, "AXParent"))
        {
            element = parent
            hops += 1
        }
        guard AX.role(element).hasPrefix("AXRow") else { throw NotFound(description: "the match isn't in a row") }
        try AX.set(element, "AXSelected", NSNumber(value: true))
        print("selected the row")
    }

    static func window(_ options: Options, _ process: RunningProcess) throws -> AXUIElement {
        try AX.window(process, title: options.value("--window"))
    }

    static func minimize(_ options: Options) throws {
        try Safety.checkAll()
        guard options.words.count > 2, ["on", "off"].contains(options.words[1]) else {
            throw UsageError(description: "minimize on|off <app>")
        }
        let process = try appArgument(options, 2)
        try Safety.checkTarget(process)
        let on = options.words[1] == "on"
        let target = try window(options, process)
        try AX.set(target, "AXMinimized", NSNumber(value: on))
        print("AXMinimized \(on) on \(process.publicName)")
    }

    static func fullscreen(_ options: Options) throws {
        try Safety.checkAll()
        guard options.words.count > 2, ["on", "off"].contains(options.words[1]) else {
            throw UsageError(description: "fullscreen on|off <app>")
        }
        let process = try appArgument(options, 2)
        try Safety.checkTarget(process)
        let on = options.words[1] == "on"
        try AX.set(try window(options, process), "AXFullScreen", NSNumber(value: on))
        print("AXFullScreen \(on) on \(process.publicName)")
    }

    static func position(_ options: Options) throws {
        try Safety.checkAll()
        let process = try appArgument(options, 1)
        // Terminal's windows go in the left third (§6 "Places"): moving a window clicks nothing in
        // it, so Terminal may be placed, though never clicked or pressed.
        if process.bundle != "com.apple.Terminal" { try Safety.checkTarget(process) }
        let numbers = options.words.dropFirst(2).compactMap(Double.init)
        guard numbers.count == 2 || numbers.count == 4 else {
            throw UsageError(description: "position <app> <x> <y> [<w> <h>]")
        }
        let target = try window(options, process)
        let wanted = CGRect(
            x: numbers[0], y: numbers[1], width: numbers.count == 4 ? numbers[2] : 0,
            height: numbers.count == 4 ? numbers[3] : 0)
        if numbers.count == 4 {
            var size = wanted.size
            guard let value = AXValueCreate(.cgSize, &size) else { throw Failure(description: "can't make a size") }
            try AX.set(target, "AXSize", value)
        }
        var origin = wanted.origin
        guard let value = AXValueCreate(.cgPoint, &origin) else { throw Failure(description: "can't make a point") }
        try AX.set(target, "AXPosition", value)
        print("\(process.publicName)'s window at \(AX.frame(target).map(describe) ?? "unknown")")
    }

    static func banner(_ options: Options) throws {
        try Safety.checkAll()
        guard options.words.count > 1 else { throw UsageError(description: "banner <text>") }
        let text = options.words[1]
        let seconds = try options.number("--seconds", default: 10)
        let start = Date()
        var center = try? Processes.app("com.apple.notificationcenterui")
        while Date().timeIntervalSince(start) < seconds {
            if center == nil { center = try? Processes.app("com.apple.notificationcenterui") }
            if let center {
                let found = AX.find(in: AX.application(center), text: text, role: nil, depth: 14)
                if var element = found.first {
                    let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                    if options.has("--probe") {
                        print("banner found after \(elapsed) ms: \(AX.role(element))")
                        return
                    }
                    var hops = 0
                    while !AX.actions(element).contains("AXPress"), hops < 4,
                        let parent = AX.element(AX.attribute(element, "AXParent"))
                    {
                        element = parent
                        hops += 1
                    }
                    if AX.actions(element).contains("AXPress") {
                        try AX.perform(element, "AXPress")
                        print("banner found after \(elapsed) ms; pressed")
                    } else if let frame = AX.frame(element) {
                        let point = CGPoint(x: frame.midX, y: frame.midY)
                        try Safety.checkPoint(point)
                        try Events.click(point, modifier: [], double: false, tap: Events.tap(options))
                        print("banner found after \(elapsed) ms; clicked at its centre")
                    } else {
                        throw Failure(description: "the banner can't be pressed or clicked")
                    }
                    return
                }
            }
            Events.pause(0.25)
        }
        throw NotFound(description: "no banner matching \(text) within \(Int(seconds)) s")
    }

    static func quit(_ options: Options) throws {
        try Safety.checkAll()
        let process = try appArgument(options, 1)
        try Safety.checkTarget(process)
        guard !["com.apple.finder", "com.apple.dock", "com.apple.notificationcenterui"].contains(process.bundle) else {
            throw Refusal(description: "\(process.name) is never quit")
        }
        try AX.perform(try menuItem(process, command: "Q"), "AXPress")
        print("pressed Quit in \(process.publicName)")
    }

    static func frame(_ options: Options) throws {
        try Safety.checkAll()
        if let title = options.value("--dock") {
            let dock = try Processes.app("com.apple.dock")
            let items = AX.find(in: AX.application(dock), text: title, role: "AXDockItem", depth: 6)
            // A minimized window's tile first, then the app's.
            let item = items.first { AX.role($0).contains("Minimized") } ?? items.first
            guard let item, let rect = AX.frame(item) else { throw NotFound(description: "no Dock tile for \(title)") }
            print("\(describe(rect)) \(AX.role(item))")
            return
        }
        let process = try readTarget(options)
        let rect: CGRect?
        if let text = options.value("--match") {
            rect = AX.frame(try match(process, text, options))
        } else if options.has("--minimize-button") {
            let button = AX.element(AX.attribute(try window(options, process), "AXMinimizeButton"))
            guard let button else { throw NotFound(description: "the window has no minimize button") }
            rect = AX.frame(button)
        } else {
            rect = AX.frame(try window(options, process))
        }
        guard let rect else { throw Failure(description: "no frame") }
        print(describe(rect))
    }

    /// The app's focused (else main) window title: System Settings' pane, say.
    static func title(_ options: Options) throws {
        try Safety.checkAll()
        let process = try readTarget(options)
        guard process.isPublic else { throw Refusal(description: "another app's titles aren't read") }
        let app = AX.application(process)
        let window = AX.element(AX.attribute(app, "AXFocusedWindow")) ?? AX.element(AX.attribute(app, "AXMainWindow"))
        guard let window else { throw NotFound(description: "\(process.publicName) has no window") }
        print("title: \(AX.string(window, "AXTitle") ?? "")")
    }

    static func hit(_ options: Options) throws {
        try Safety.checkAll()
        let point = try options.point(at: 1)
        var element: AXUIElement?
        guard
            AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &element)
                == .success, let found = element, let pid = AX.pid(found)
        else { throw NotFound(description: "no element at (\(Int(point.x)), \(Int(point.y)))") }
        let owner = Processes.process(pid)
        print("process: \(owner.publicName) (\(owner.isPublic ? owner.bundle : "-"), pid \(pid))")
        if let window = Screen.topWindow(at: point) {
            print("top window: \(window.id), owner \(Processes.process(window.pid).publicName), layer \(window.layer)")
        }
        guard owner.isPublic else { return }
        var current: AXUIElement? = found
        var level = 0
        while let item = current, level < 12 {
            let frame = AX.frame(item).map(describe) ?? "-"
            print(
                "\(String(repeating: "  ", count: level))\(AX.role(item)) \"\(AX.label(item))\" frame \(frame) actions \(AX.actions(item).joined(separator: ","))"
            )
            current = AX.element(AX.attribute(item, "AXParent"))
            level += 1
        }
    }

    static func tree(_ options: Options) throws {
        try Safety.checkAll()
        let process = try readTarget(options)
        let depth = Int(try options.number("--depth", default: 12))
        let inside = try options.rect("--inside")
        let text = options.value("--match")
        let isBatteryPulse = process.bundle == Rules.batteryPulse
        if process.bundle == "com.apple.systempreferences" {
            guard let text else { throw Refusal(description: "System Settings' tree is read only as --match <text>") }
            let count = AX.find(in: AX.application(process), text: text, role: nil, depth: depth + 10).count
            print("match \(text): \(count > 0 ? "found" : "not found") (\(count))")
            return
        }
        guard isBatteryPulse || text != nil || inside != nil else {
            throw Refusal(description: "another app's tree is read only as --match <text> or --inside x y w h")
        }
        let roots =
            text.map {
                AX.find(in: AX.application(process), text: $0, role: options.value("--role"), depth: depth + 10)
            }
            ?? [AX.application(process)]
        var printed = 0
        func walk(_ element: AXUIElement, _ level: Int) {
            guard level <= depth, printed < 2000 else { return }
            let frame = AX.frame(element)
            let isInside = inside.map { box in frame.map { box.insetBy(dx: -2, dy: -2).contains($0) } ?? false } ?? true
            if isInside {
                print(
                    "\(String(repeating: "  ", count: level))\(AX.role(element)) \"\(AX.label(element))\" value \(AX.value(element)) frame \(frame.map(describe) ?? "-")"
                )
                printed += 1
            }
            for child in AX.children(element) { walk(child, level + 1) }
        }
        for root in roots.prefix(20) { walk(root, 0) }
        if printed == 0 { throw NotFound(description: "nothing matched") }
    }

    static func windows(_ options: Options) throws {
        // CGWindowList only: no AX into any process, so the queue may call it during a run.
        let all = Screen.windows()
        let filter = try options.value("--app").map { try Processes.app($0) }
        if options.has("--status-item") {
            let process = try filter ?? Processes.app(Rules.batteryPulse)
            let items = all.filter { $0.pid == process.pid && $0.layer == 25 }
            guard let item = items.first else { throw NotFound(description: "no menu bar item window") }
            print("\(item.id) \(describe(item.bounds))")
            return
        }
        if options.has("--main") {
            try mainWindowCheck(all, allowCover: options.value("--allow-cover"))
            return
        }
        for window in all where filter.map({ $0.pid == window.pid }) ?? true {
            let owner = Processes.process(window.pid)
            let name = owner.bundle == Rules.batteryPulse ? " \"\(window.name)\"" : ""
            print(
                "\(window.id)\tlayer \(window.layer)\t\(owner.publicName)\t\(describe(window.bounds))\talpha \(window.alpha)\(name)"
            )
        }
    }

    /// BatteryPulse's main window: on screen, inside a display, not covered (but by the allowed
    /// app) and not full screen.
    static func mainWindowCheck(_ all: [Window], allowCover: String?) throws {
        let app = try Processes.app(Rules.batteryPulse)
        let own = all.filter { $0.pid == app.pid && $0.layer == 0 }
        guard
            let main = own.first(where: { $0.name == "BatteryPulse" })
                ?? own.max(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height })
        else { throw NotFound(description: "BatteryPulse's main window isn't on screen") }
        var problems: [String] = []
        let displays = Screen.displays()
        if !displays.contains(where: { $0.contains(main.bounds) }) { problems.append("not inside a display") }
        if displays.contains(where: { $0.equalTo(main.bounds) }) { problems.append("full screen") }
        let allowed = try allowCover.map { try Processes.app($0).pid }
        if let index = all.firstIndex(where: { $0.id == main.id }) {
            for window in all[..<index]
            where window.alpha > 0.01 && window.bounds.intersects(main.bounds) && window.pid != app.pid {
                if let allowed, window.pid == allowed { continue }
                problems.append("covered by \(Processes.process(window.pid).publicName) (layer \(window.layer))")
            }
        }
        print(
            "main window \(main.id) at \(describe(main.bounds)): \(problems.isEmpty ? "ok" : problems.joined(separator: "; "))"
        )
        if !problems.isEmpty { throw Failure(description: "the main window isn't clear") }
    }

    static func idle() {
        let hid = Screen.hidIdleSeconds().map { String(format: "%.1f", $0) } ?? "unknown"
        print(
            "hid_idle_s=\(hid) hid_state_s=\(String(format: "%.1f", Screen.secondsSinceInput(.hidSystemState))) session_state_s=\(String(format: "%.1f", Screen.secondsSinceInput(.combinedSessionState)))"
        )
    }

    static func locked() {
        print(
            "locked=\(Screen.isLocked() ? "yes" : "no") lid=\(Screen.isLidClosed() ? "closed" : "open") console=\(Screen.isOnConsole() ? "yes" : "no")"
        )
    }

    static func thermal() {
        let state: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: state = "nominal"
        case .fair: state = "fair"
        case .serious: state = "serious"
        case .critical: state = "critical"
        @unknown default: state = "unknown"
        }
        let hid = Screen.hidIdleSeconds().map { String(format: "%.1f", $0) } ?? "unknown"
        print("thermal=\(state) lowpower=\(ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 : 0) hid_idle_s=\(hid)")
    }

    /// The queue sampler's one line: HIDIdleTime, the lock and the lid, the thermal state and Low
    /// Power Mode, with no AX call.
    static func sample() {
        let hid = Screen.hidIdleSeconds().map { String(format: "%.1f", $0) } ?? "unknown"
        let state: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: state = "nominal"
        case .fair: state = "fair"
        case .serious: state = "serious"
        case .critical: state = "critical"
        @unknown default: state = "unknown"
        }
        print(
            "hid_idle_s=\(hid) locked=\(Screen.isLocked() ? "yes" : "no") lid=\(Screen.isLidClosed() ? "closed" : "open") thermal=\(state) lowpower=\(ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 : 0)"
        )
    }

    static func access() {
        let yes = { (value: Bool) in value ? "yes" : "no" }
        print(
            "ax_trusted=\(yes(AXIsProcessTrusted())) post_events=\(yes(CGPreflightPostEventAccess())) screen_capture=\(yes(CGPreflightScreenCaptureAccess()))"
        )
    }

    static func screen() {
        let corners = Screen.corners().map { "\($0.name)=\($0.action)" }.joined(separator: " ")
        print(
            "main=\(describe(CGDisplayBounds(CGMainDisplayID()))) scale=\(Screen.scale()) displays=\(Screen.displays().count) corners \(corners)"
        )
    }

    static func run(_ arguments: [String]) throws {
        let options = try Options(Array(arguments.dropFirst()))
        guard let command = options.words.first else { throw UsageError(description: usage) }
        switch command {
        case "click": try click(options)
        case "move": try move(options)
        case "drag": try drag(options)
        case "scroll": try scroll(options)
        case "press": try press(options)
        case "select-row": try selectRow(options)
        case "minimize": try minimize(options)
        case "fullscreen": try fullscreen(options)
        case "position": try position(options)
        case "banner": try banner(options)
        case "quit": try quit(options)
        case "frame": try frame(options)
        case "hit": try hit(options)
        case "title": try title(options)
        case "tree": try tree(options)
        case "windows": try windows(options)
        case "idle": idle()
        case "locked": locked()
        case "thermal": thermal()
        case "sample": sample()
        case "access": access()
        case "screen": screen()
        case "guard":
            try Safety.checkNow()
            print("guard: clear")
        default: throw UsageError(description: usage)
        }
    }

    static let usage =
        "usage: ui click|move|drag|scroll|press|select-row|minimize|fullscreen|position|banner|quit|frame|title|hit|tree|windows|idle|locked|thermal|sample|access|screen|guard ... (see ui.swift)"
}

do {
    try Command.run(CommandLine.arguments)
} catch let error as Refusal {
    FileHandle.standardError.write(Data("ui: refused: \(error)\n".utf8))
    exit(3)
} catch let error as UsageError {
    FileHandle.standardError.write(Data("ui: \(error)\n".utf8))
    exit(2)
} catch let error as NotFound {
    FileHandle.standardError.write(Data("ui: not found: \(error)\n".utf8))
    exit(4)
} catch {
    FileHandle.standardError.write(Data("ui: \(error)\n".utf8))
    exit(1)
}
