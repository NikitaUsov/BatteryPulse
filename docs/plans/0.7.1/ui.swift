// The hands of the hands-free sessions of BatteryPulse 0.7.0 (0.7.0's PLAN.md §6.2;
// Session R and its short sessions, built on 0.6.2's Session B): Accessibility (AX), posted mouse
// events (CGEvent) and the window list (CGWindowList), with safety rules of its own, so they don't
// rest on the Claude session alone. The session script builds it beside `frames` and is its only
// caller (`m5-session.sh ui <command>`):
//
//   xcrun swiftc -O docs/plans/0.7.1/ui.swift -o ~/bp-070/<R|C|H|D3>/bin/ui
//
// Copied from docs/plans/0.7.0/ at 0.7.0's release, which shipped without Session R, for 0.7.1's
// M5 session. PLAN.md is 0.7.0's docs/plans/0.7.0/PLAN.md, readable at
// <keep> in refs/pull/13/head.
//
// Its folder is the session's: the folder above the bin/ it runs from, which must be
// ~/bp-070/R, C, H or D3 of the account's own home; run from anywhere else it refuses everything.
//
// A point is global display points, the top left of the main display at 0,0, given as `<x> <y>`,
// or as `--image <png> <x> <y>`: pixels of a full-screen shot of the main display (the script's
// `shot`), converted to points. Never computer use's scaled coordinates.
//
// Every click, move and scroll names what it is aimed at, and acts only when that is what lies at
// the point, by AX and by the topmost window (--cg-only: by the window alone). AX is asked first
// and the window list last, and a fresh window list is read again just before each button, wheel
// or move event: the same topmost window (ID and process) must still be there.
//   --expect <app or bundle> [--window <CGWindowID>]  BatteryPulse, System Settings, TextEdit's
//                                                    cover window, Accessibility Inspector, Xcode's
//                                                    window of the frozen worktree, a BatteryPulse
//                                                    widget in its host, Control Center's clock
//   --expect desktop                                 the bare desktop: a desktop-level window of
//                                                    Finder, WindowManager or the wallpaper, or
//                                                    WindowManager's revealed-desktop window
//                                                    (layer 18, which a click ends), no menu bar,
//                                                    and an element under AX that is no icon,
//                                                    control or menu; one plain click only
//   --expect dock-tile (--new-since <file> | --dock-title <title>)   click only: the minimized
//                                                    window's own Dock tile (see frame --dock)
//
// One window is never the topmost and never covers anything: the Dock's full-display overlay
// (`Rules.isDockOverlay`). On macOS 27.2 the Dock owns a window at layer 20 whose bounds equal a
// display's, on screen all the time; it lets clicks through. Only that exact window is passed over
// (its owner name and the Dock's own pid, layer 20, a display's bounds, any alpha), by the hit
// tests, the occlusion check, the desktop check and `recheck`; every other window at layer 20 or
// above still counts. The Dock stays unclickable but for the minimized window's own tile: under the
// overlay AX must still find the expected app at the point, and by the window list alone a point
// on the Dock's bar (its AX frame), or any point while the Dock shows a menu, is refused.
//
// Actions (each passes the safety rules below first):
//   click <point> --expect … [--shift | --control] [--double] [--cg-only] [--probe]
//                                                    a left click; the modifier as flagsChanged;
//                                                    --cg-only hit-tests by the window list alone
//                                                    (no AX call into BatteryPulse);
//                                                    --probe checks the point and clicks nothing
//   click --ax <app> <text> [--shift | --control]    at the centre of the element that matches;
//                                                    `click --ax "Control Center" clock` finds the
//                                                    clock by its identifier (Notification Center)
//   click --expect dock-tile (--new-since <file> | --dock-title <title>) [--shift]
//   move <point> --expect … | move --here           --here: a 0-pixel move (proof P6)
//   drag <point> <point> [--steps n] [--seconds s]   slow, in steps: from a widget in its host to
//                                                    the desktop or the widget layer, never onto an
//                                                    icon or the Dock
//   scroll <point> <lines> --expect …                positive lines scroll down
//   press <app> <text> [--role r] [--within role] [--index n] [--action AXPress]
//   press <app> --menu-cmd <char>                    the menu item with that Command key and no other
//                                                    modifier (Settings… is ",", Close "W")
//   press BatteryPulse --status-item                 an AX press on the menu bar item (its popover
//                                                    opens or closes): macOS 27.2 lists no window
//                                                    for it, so no click there passes the checks
//   select-row <app> <text>                          AXSelected on the matching row
//   minimize on|off <app> [--window <title>]         AXMinimized
//   fullscreen on|off <app> [--window <title>]       AXFullScreen (no keystroke)
//   position <app> <x> <y> [<width> <height>] [--window <title>]   (Terminal too: placed, never
//                                                    clicked)
//   close <app> --window <title>                     an AX press on that window's close button
//   banner <text> [--seconds n] [--probe]            finds the banner with that text (the
//                                                    notification's own body) in Notification
//                                                    Center's AX tree and presses it, only inside a
//                                                    BatteryPulse banner and never one of its
//                                                    buttons (--probe: only finds it)
//   quit <app>                                       an AX press on the app's own Quit menu item:
//                                                    BatteryPulse, or a process the script opened
//                                                    (launched.tsv), never his own copy
// Reads:
//   frame <app> [--window <title> | --minimize-button | --match <text>]
//   frame BatteryPulse --status-item                 the menu bar item's frame by AX (the app's
//                                                    AXExtrasMenuBar): macOS 27.2 lists no window
//                                                    for it in CGWindowList (0.6.2's P11)
//   frame --widgets                                  the frames of the BatteryPulse-labelled widget
//                                                    elements of the widget hosts, on screen now
//                                                    (desktop or Notification Center), one per
//                                                    line, no labels
//   frame --dock --list                              every minimized window's Dock tile: its frame
//                                                    and a hash of its title (no title printed)
//   frame --dock (--new-since <file> | --dock-title <title> | <title>)
//                                                    the tile that appeared since the --list file,
//                                                    else the one tile with exactly that title;
//                                                    never an app's tile
//   title BatteryPulse | "System Settings"           its focused window's title
//   pane-state [--expect <pane>]                     System Settings: the sidebar's selected row,
//                                                    the title, and whether they are that pane's
//                                                    (proof P8's names)
//   hit <point>                                      the element there: process, role, the parent
//                                                    chain and the frames (proof P1); labels only
//                                                    inside BatteryPulse
//   tree <app> | --app <app> [--match <text>] [--inside x y w h] [--depth n]
//   windows [--app <name>] [--main [--allow-cover <app>]] [--status-item]
//   idle | locked | thermal | sample | access | screen | guard
//                                                    sample: idle, locked, the screen saver and
//                                                    thermal in one line
//   Options of every command: --tap hid|session (else the folder's ui-tap, proof P6's, else hid).
//
// What the script recorded comes from files in the session's folder, never from the environment:
// ui-hosts (proof P1's widget hosts), ui-panes (proof P8's panes), widgets.tsv (`widget`'s frames),
// ui-tap and launched.tsv; the fence from ~/bp-070/R (ready, day-ended, arm.pid). The home folder
// is the account's own, from the user database (getpwuid), never HOME; with CFFIXED_USER_HOME set
// it refuses everything.
//
// Safety rules (exit status 3 when one refuses):
//   - no key presses at all: only a Shift or Control modifier, as a flagsChanged event, around a
//     click; never Esc, which would end the Claude session's turn. SIGINT, SIGTERM and SIGHUP wait
//     while a button or a modifier is down, and every acting command first releases a Shift,
//     Control or left button that the session's state shows down and the hardware's doesn't (a ui
//     killed mid-press);
//   - a click, move or scroll acts only where its --expect holds (above); AX actions target only
//     BatteryPulse, System Settings, TextEdit's cover window, Accessibility Inspector and Xcode's
//     window of the session's frozen worktree (<folder>/run). Finder is only ever the bare desktop,
//     the Dock only the minimized window's tile, Control Center only its clock; a widget host only
//     at a BatteryPulse widget (a BatteryPulse label in the AX chain; by the window list alone, a
//     recorded frame at the desktop's widget layer); the hosts in ui-hosts count only when they
//     are widget hosts;
//   - it always refuses SecurityAgent, UserNotificationCenter, CoreServicesUIAgent, coreautha,
//     loginwindow, a TCC prompt and Terminal, and refuses any action while one of them, the screen
//     saver or loginwindow shows a window (Terminal's own windows aside);
//   - System Settings: it acts only while every window shows a pane proof P8 confirmed
//     (ui-panes, and only P8's own panes) or Accessibility → Display, by the sidebar's selection
//     and the title, or by the title alone where P8 recorded the sidebar as unreadable ("-": macOS
//     27.2, Session B), and never while the sidebar or the title is Privacy & Security, Users &
//     Groups, Touch ID & Password, Lock Screen, Passwords or Login Password, nor on an element
//     whose label names one of them;
//   - it refuses everything that touches AX or posts an event while the screen is locked or the
//     lid is closed, and while ~/bp-070/R/ready exists without a newer ~/bp-070/R/day-ended (the
//     logged day), unless Session R's arm window (its pid and start time in arm.pid) is among its
//     own ancestors;
//   - it refuses any point within 20 points of a hot corner set to Start Screen Saver, Put Display
//     to Sleep or Lock Screen;
//   - `guard` exits 3 when any of these holds now, or System Settings shows a pane it never acts in.
// Exit status: 0 done, 1 failed, 2 a wrong call, 3 refused, 4 not found.
//
// Privacy: process names are printed only for BatteryPulse and Apple's own processes ("another
// app" otherwise); element labels only for BatteryPulse's elements and those inside an element
// labelled BatteryPulse (a title or description that begins with "BatteryPulse", or BatteryPulse's
// identifier); `tree` of a widget host only inside a recorded widget frame, of System
// Settings only whether the match exists, of another app only roles and frames. Every call is
// public API.
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

/// What a click, move or scroll is aimed at (`--expect`).
enum Expectation {
    case app(String)
    /// Notification Center at a banner that `banner` found by its own text.
    case banner
    case desktop
    case dockTile(AXUIElement)
}

enum Rules {
    static let batteryPulse = "io.github.nikitausov.BatteryPulse"
    static let settings = "com.apple.systempreferences"
    static let notificationCenter = "com.apple.notificationcenterui"
    static let finder = "com.apple.finder"
    static let dock = "com.apple.dock"
    static let controlCenter = "com.apple.controlcenter"
    static let terminal = "com.apple.Terminal"
    static let textEdit = "com.apple.TextEdit"
    static let xcode = "com.apple.dt.Xcode"
    /// The apps an AX action (press, select-row, minimize, fullscreen, position, close, quit, a menu
    /// command) may target. Finder, the Dock and Control Center never are; TextEdit and Xcode only in
    /// the session's own window (`OwnWindows`).
    static let targetBundles: Set<String> = [
        batteryPulse, settings, textEdit, "com.apple.AccessibilityInspector", xcode,
    ]
    /// The widget hosts known before proof P1; P1 may add a WidgetKit host (ui-hosts).
    static let builtInHosts: Set<String> = [notificationCenter, "com.apple.chronod"]
    /// Control Center's one approved element: the clock, which opens Notification Center (P2).
    static let clockIdentifier = "com.apple.menuextra.clock"
    /// The bare desktop's owners: Finder's desktop window, WindowManager and the wallpaper.
    static let desktopBundles: Set<String> = [finder, "com.apple.WindowManager"]
    static let desktopPrefixes = ["com.apple.wallpaper"]
    /// The window server's own windows (the menu bar's backdrop, the cursor), by owner name: never
    /// the topmost window of a hit test.
    static let windowServer: Set<String> = ["Window Server", "WindowServer"]
    /// Never acted on, whatever the approved list says.
    static let refusedNames: Set<String> = [
        "SecurityAgent", "UserNotificationCenter", "CoreServicesUIAgent", "coreautha", "loginwindow",
        "universalAccessAuthWarn", "tccd", "Terminal", "SystemUIServer-TCC",
    ]
    static let refusedBundles: Set<String> = [
        "com.apple.SecurityAgent", "com.apple.UserNotificationCenter", "com.apple.coreservices.uiagent",
        "com.apple.loginwindow", terminal, "com.apple.LocalAuthentication.UIAgent",
        "com.apple.tccd", "com.apple.accessibility.universalAccessAuthWarn",
    ]
    static let screenSaverNames = ["ScreenSaverEngine", "legacyScreenSaver"]
    /// AX roles that are a file's icon or its name, a control or a menu (Finder's menu bar, when it
    /// is frontmost): never "the bare desktop".
    static let iconRoles: Set<String> = [
        "AXImage", "AXDockItem", "AXTextField", "AXStaticText", "AXButton", "AXCell", "AXRow", "AXCheckBox",
        "AXMenuItem", "AXMenuButton", "AXPopUpButton", "AXRadioButton", "AXLink", "AXSlider", "AXIncrementor",
        "AXMenuBar", "AXMenuBarItem", "AXMenu",
    ]
    /// Apps known by another name than their process.
    static let aliases: [String: String] = [
        "notification center": notificationCenter, "notificationcenter": notificationCenter,
        "system settings": settings, "dock": dock, "finder": finder, "control center": controlCenter,
        "controlcenter": controlCenter, "batterypulse": batteryPulse, "textedit": textEdit,
        "xcode": xcode, "accessibility inspector": "com.apple.AccessibilityInspector",
    ]

    static func bundle(for query: String) -> String { aliases[query.lowercased()] ?? query }

    static func isRefused(_ process: RunningProcess) -> Bool {
        refusedNames.contains(process.name) || refusedBundles.contains(process.bundle)
            || process.name.localizedCaseInsensitiveContains("tcc")
    }

    static func isTerminal(_ process: RunningProcess) -> Bool {
        process.bundle == terminal || process.name == "Terminal"
    }

    static func isLoginWindow(_ process: RunningProcess) -> Bool {
        process.name == "loginwindow" || process.bundle == "com.apple.loginwindow"
    }

    static func isScreenSaver(_ process: RunningProcess, owner: String = "") -> Bool {
        screenSaverNames.contains { process.name.hasPrefix($0) || owner.hasPrefix($0) }
            || process.bundle.hasPrefix("com.apple.ScreenSaver")
    }

    static func isDesktopOwner(_ process: RunningProcess) -> Bool {
        desktopBundles.contains(process.bundle) || desktopPrefixes.contains { process.bundle.hasPrefix($0) }
    }

    /// The topmost window of the bare desktop: a desktop-level window of Finder, WindowManager or
    /// the wallpaper, or the Dock's desktop picture far below every other level (where a release
    /// still draws it there); never the Dock's own bar, which sits above level 0.
    static func isDesktopWindow(_ window: Window, _ owner: RunningProcess) -> Bool {
        guard window.layer < 0 else { return false }
        return isDesktopOwner(owner) || (owner.bundle == dock && window.layer < -1_000_000)
    }

    /// The layer of the window WindowManager shows while a click on the wallpaper has revealed the
    /// desktop (macOS 27.2: Session B's desktop clicks left it on, over the windows they pushed
    /// aside). A click on the bare desktop under it ends that state, so a desktop click may land on
    /// it; nothing else treats it as the desktop.
    static let revealDesktopLevel = 18

    static func isRevealDesktopWindow(_ window: Window, _ owner: RunningProcess) -> Bool {
        owner.bundle == "com.apple.WindowManager" && window.layer == revealDesktopLevel
    }

    /// The Dock's own window level (kCGDockWindowLevel).
    static let dockLevel = 20

    /// The Dock's full-display overlay, the one window the topmost-window and occlusion tests pass
    /// over (the header's exception). Session B's first attempt (2026-10-27, macOS 27.2 26B123,
    /// PLAN.md Appendix C) met it: CGWindowList listed a window of the Dock at layer 20 with bounds
    /// 0 0 1710 1107 (the M5's whole display) and alpha 1 all evening, while every window below it
    /// showed and took clicks, so every occlusion and desktop check failed on it. Exact: the owner
    /// name "Dock", a pid that is the Dock's own process (com.apple.dock), layer 20 and bounds equal
    /// to an active display's; any alpha. Anything else at layer 20 or above still counts.
    static func isDockOverlay(_ window: Window, displays: [CGRect]) -> Bool {
        guard window.owner == "Dock", window.layer == dockLevel,
            displays.contains(where: { $0.equalTo(window.bounds) })
        else { return false }
        return Processes.process(window.pid).bundle == dock
    }

    static func isWidgetHostCandidate(_ bundle: String) -> Bool {
        builtInHosts.contains(bundle) || bundle.lowercased().hasPrefix("com.apple.widgetkit.")
    }

    /// The widget hosts: the known ones, and ui-hosts' entries (proof P1's, split on any
    /// whitespace) that are widget hosts; any other entry is ignored.
    static func widgetHosts() -> Set<String> {
        let listed = Files.text("ui-hosts").split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return builtInHosts.union(listed.filter(isWidgetHostCandidate))
    }

    /// The owners a click, move or scroll may be aimed at.
    static func isPointApproved(_ bundle: String) -> Bool {
        targetBundles.contains(bundle) || bundle == controlCenter || widgetHosts().contains(bundle)
    }

    /// The largest frame of each family's widget, in points, with room to spare (the script's
    /// `widget` checks the same): a frame in pixels is twice as large.
    static let widgetLimits: [String: CGSize] = [
        "small": CGSize(width: 220, height: 220), "medium": CGSize(width: 440, height: 220),
        "large": CGSize(width: 440, height: 460), "xlarge": CGSize(width: 880, height: 460),
    ]

    /// A recorded widget's family: its name, or the part after the last "-" ("accessories-small").
    static func family(_ name: String) -> String {
        name.split(separator: "-").last.map(String.init) ?? name
    }

    /// The widget frames the script recorded (widgets.tsv: "<name>\t<x> <y> <w> <h>" per line), in
    /// points; a frame larger than its family's widget is ignored.
    static func widgetFrames() -> [CGRect] {
        Files.text("widgets.tsv").split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t").map(String.init)
            guard fields.count == 2, let limit = widgetLimits[family(fields[0])] else { return nil }
            let numbers = fields[1].split(whereSeparator: { $0.isWhitespace }).compactMap { Double(String($0)) }
            guard numbers.count == 4, numbers[2] >= 20, numbers[3] >= 20, numbers[2] <= Double(limit.width),
                numbers[3] <= Double(limit.height)
            else { return nil }
            return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
        }
    }

    static func isInsideWidget(_ point: CGPoint) -> Bool {
        widgetFrames().contains { $0.insetBy(dx: -2, dy: -2).contains(point) }
    }

    /// A rectangle that is one of the recorded widget frames, within 2 points.
    static func isRecordedWidget(_ rect: CGRect) -> Bool {
        widgetFrames().contains {
            abs($0.minX - rect.minX) <= 2 && abs($0.minY - rect.minY) <= 2 && abs($0.width - rect.width) <= 2
                && abs($0.height - rect.height) <= 2
        }
    }
}

// MARK: - The account and the script's files

/// The account ui runs as.
enum Account {
    /// Its home folder, from the user database: never HOME or CFFIXED_USER_HOME, which the caller
    /// sets (NSHomeDirectory and CFPreferences follow the latter, so `run` refuses it).
    static let home: String? = {
        guard let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir else { return nil }
        let path = String(cString: directory)
        return path.hasPrefix("/") ? path : nil
    }()
}

/// What the script recorded in the session's folder: ui-hosts, ui-panes, widgets.tsv, ui-tap and
/// launched.tsv. A missing file reads as empty.
enum Files {
    static func text(_ name: String) -> String {
        (try? String(contentsOfFile: Safety.home + "/" + name, encoding: .utf8)) ?? ""
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
        let wanted = Rules.bundle(for: query)
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

    static func info(_ pid: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return info
    }

    static func parent(_ pid: pid_t) -> pid_t? { info(pid).map { pid_t($0.pbi_ppid) } }

    /// When the process started, in seconds since 1970 (what `ps -o lstart` shows).
    static func startTime(_ pid: pid_t) -> Int? { info(pid).map { Int($0.pbi_start_tvsec) } }

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

    static func parent(_ element: AXUIElement) -> AXUIElement? { self.element(attribute(element, "AXParent")) }

    /// The element, then its parents, at most `hops` of them.
    static func chain(_ element: AXUIElement, hops: Int) -> [AXUIElement] {
        var chain = [element]
        var current = element
        while chain.count <= hops, let next = parent(current) {
            chain.append(next)
            current = next
        }
        return chain
    }

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

    /// The element at a point, by the system-wide hit test (it asks the app that owns the point).
    static func element(at point: CGPoint) -> AXUIElement? {
        var found: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &found)
            == .success
        else { return nil }
        return found
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

    /// A file's icon or its name, or a control: what "the bare desktop" never is.
    static func isIconLike(_ element: AXUIElement) -> Bool {
        let role = string(element, "AXRole") ?? ""
        let subrole = string(element, "AXSubrole") ?? ""
        return Rules.iconRoles.contains(role) || subrole.localizedCaseInsensitiveContains("icon")
            || attribute(element, "AXFilename") != nil
    }

    /// Whether the element or one of its first `hops` parents carries that identifier.
    static func hasIdentifier(_ element: AXUIElement, _ identifier: String, hops: Int) -> Bool {
        chain(element, hops: hops).contains { string($0, "AXIdentifier") == identifier }
    }

    /// Whether the element itself is BatteryPulse's by its label: a title or description that
    /// begins with "BatteryPulse", or an identifier that begins with it or with BatteryPulse's bundle
    /// identifier. Never a value or help text, and never the name in the middle of a text (a mail
    /// banner's "[…/BatteryPulse] …").
    static func isBatteryPulseLabelled(_ element: AXUIElement) -> Bool {
        ["AXTitle", "AXDescription", "AXIdentifier"].contains { name in
            let text = (string(element, name) ?? "").trimmingCharacters(in: .whitespaces)
            return text.lowercased().hasPrefix("batterypulse") || text.hasPrefix(Rules.batteryPulse)
        }
    }

    /// Whether the element or one of its parents is labelled BatteryPulse (a widget's container).
    static func isInsideBatteryPulse(_ element: AXUIElement) -> Bool {
        chain(element, hops: 10).contains(where: isBatteryPulseLabelled)
    }

    /// Whether the element is `target` or lies inside it, within `hops` parents.
    static func isOrIsInside(_ element: AXUIElement, _ target: AXUIElement, hops: Int) -> Bool {
        chain(element, hops: hops).contains { CFEqual($0, target) }
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

    /// The focused window, else the main one.
    static func frontWindow(_ process: RunningProcess) -> AXUIElement? {
        let app = application(process)
        return element(attribute(app, "AXFocusedWindow")) ?? element(attribute(app, "AXMainWindow"))
    }

    /// The window titled exactly `title` (or `title` with a file extension: TextEdit may show it),
    /// else the main window, else the first one.
    static func window(_ process: RunningProcess, title: String?) throws -> AXUIElement {
        let all = windows(process)
        if let title {
            let match = all.first { window in
                let shown = string(window, "AXTitle") ?? ""
                return shown == title || (shown as NSString).deletingPathExtension == title
            }
            if let match { return match }
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

// MARK: - TextEdit's and Xcode's own windows

/// TextEdit and Xcode hold his documents and projects: ui acts only in the session's own window of
/// each, TextEdit's cover file and Xcode's window of the frozen worktree (WP-18's package).
enum OwnWindows {
    static func resolved(_ path: String) -> String { URL(fileURLWithPath: path).resolvingSymlinksInPath().path }

    /// The window's document (AXDocument, a file URL) as a path.
    static func document(_ window: AXUIElement) -> String? {
        guard let text = AX.string(window, "AXDocument"), let url = URL(string: text), url.isFileURL else { return nil }
        return url.resolvingSymlinksInPath().path
    }

    /// Whether ui may act in that window of the process: every window of the other targets.
    static func allows(_ window: AXUIElement, of process: RunningProcess) -> Bool {
        switch process.bundle {
        case Rules.textEdit:
            return document(window) == resolved(Safety.home + "/bp-070-cover.txt")
        case Rules.xcode:
            guard let path = document(window) else { return false }
            let run = resolved(Safety.home + "/run")
            return path == run || path.hasPrefix(run + "/")
        default:
            return true
        }
    }

    static func check(_ window: AXUIElement?, of process: RunningProcess) throws {
        guard process.bundle == Rules.textEdit || process.bundle == Rules.xcode else { return }
        guard let window, allows(window, of: process) else {
            throw Refusal(
                description: "\(process.publicName): ui acts only in the session's own window (TextEdit's cover file, Xcode's frozen worktree)"
            )
        }
    }

    /// The window an element lies in: its AXWindow, else the nearest AXWindow among its parents.
    static func window(of element: AXUIElement) -> AXUIElement? {
        if let window = AX.element(AX.attribute(element, "AXWindow")) { return window }
        return AX.chain(element, hops: 40).first { AX.string($0, "AXRole") == "AXWindow" }
    }
}

// MARK: - System Settings' panes

enum Panes {
    /// Panes it never acts in, English and Russian, lowercased, as fragments of the sidebar's
    /// selection or the title ("password" covers Passwords, Login Password and Touch ID & Password).
    static let refused: [String] = [
        "privacy", "users & groups", "password", "touch id", "lock screen",
        "\u{043A}\u{043E}\u{043D}\u{0444}\u{0438}\u{0434}\u{0435}\u{043D}\u{0446}\u{0438}\u{0430}\u{043B}\u{044C}\u{043D}\u{043E}\u{0441}\u{0442}\u{044C}",
        "\u{043F}\u{043E}\u{043B}\u{044C}\u{0437}\u{043E}\u{0432}\u{0430}\u{0442}\u{0435}\u{043B}\u{0438} \u{0438} \u{0433}\u{0440}\u{0443}\u{043F}\u{043F}\u{044B}",
        "\u{043F}\u{0430}\u{0440}\u{043E}\u{043B}",
        "\u{044D}\u{043A}\u{0440}\u{0430}\u{043D} \u{0431}\u{043B}\u{043E}\u{043A}\u{0438}\u{0440}\u{043E}\u{0432}\u{043A}\u{0438}",
    ]
    /// The title each of proof P8's pane URLs should show (the script's PANES), English and Russian.
    static let expected: [String: [String]] = [
        "appearance": ["appearance", "\u{043E}\u{0444}\u{043E}\u{0440}\u{043C}\u{043B}\u{0435}\u{043D}\u{0438}\u{0435}"],
        "desktop": ["desktop", "\u{0440}\u{0430}\u{0431}\u{043E}\u{0447}\u{0438}\u{0439} \u{0441}\u{0442}\u{043E}\u{043B}"],
        "displays": ["display", "\u{0434}\u{0438}\u{0441}\u{043F}\u{043B}\u{0435}"],
        "accessibility": [
            "accessibility",
            "\u{0443}\u{043D}\u{0438}\u{0432}\u{0435}\u{0440}\u{0441}\u{0430}\u{043B}\u{044C}\u{043D}\u{044B}\u{0439} \u{0434}\u{043E}\u{0441}\u{0442}\u{0443}\u{043F}",
        ],
        "login-items": ["login items", "\u{043E}\u{0431}\u{044A}\u{0435}\u{043A}\u{0442}\u{044B} \u{0432}\u{0445}\u{043E}\u{0434}\u{0430}"],
        "battery": ["battery", "\u{0430}\u{043A}\u{043A}\u{0443}\u{043C}\u{0443}\u{043B}\u{044F}\u{0442}\u{043E}\u{0440}"],
        "date-time": ["date", "\u{0434}\u{0430}\u{0442}\u{0430}"],
        "wallpaper": ["wallpaper", "\u{043E}\u{0431}\u{043E}\u{0438}"],
        // Step 9's accessory disconnect (Session R): the pane's name is the same in Russian.
        "bluetooth": ["bluetooth"],
    ]
    /// Accessibility → Display (Text size, Increase Contrast, Reduce Transparency, motion), the one
    /// subpane allowed beyond P8's list.
    static let accessibilityDisplay: Set<String> = ["display", "\u{0434}\u{0438}\u{0441}\u{043F}\u{043B}\u{0435}\u{0439}"]

    static func isRefused(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return refused.contains { lowered.contains($0) }
    }

    static func matches(_ name: String, title: String) -> Bool {
        let lowered = title.lowercased()
        return (expected[name] ?? []).contains { lowered.contains($0) } && !isRefused(title)
    }

    /// Proof P8's confirmed panes (ui-panes: "<name>\t<sidebar>\t<title>" per line): only P8's own
    /// panes, each with that pane's title; any other line is ignored.
    static func allowed() -> [(name: String, sidebar: String, title: String)] {
        Files.text("ui-panes").split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 3, matches(fields[0], title: fields[2]), !isRefused(fields[1]) else { return nil }
            return (name: fields[0], sidebar: fields[1], title: fields[2])
        }
    }

    static func isAllowed(sidebar: String, title: String) -> Bool {
        allowed().contains { pane in
            guard pane.sidebar == sidebar else { return false }
            return pane.title == title || (pane.name == "accessibility" && accessibilityDisplay.contains(title.lowercased()))
        }
    }

    /// By the title alone, for a pane P8 confirmed while the sidebar's selection was unreadable
    /// (its ui-panes line has "-" for the sidebar): macOS 27.2 reads no selection (Session B).
    static func isAllowed(title: String) -> Bool {
        allowed().contains { pane in
            guard pane.sidebar == "-" else { return false }
            return pane.title == title || (pane.name == "accessibility" && accessibilityDisplay.contains(title.lowercased()))
        }
    }

    /// The sidebar's selected row (the first AXOutline's AXSelectedRows): its label and texts.
    static func sidebarSelection(_ window: AXUIElement) -> String? {
        guard let outline = AX.find(in: window, text: nil, role: "AXOutline", depth: 12).first,
            let row = AX.elements(outline, "AXSelectedRows").first
        else { return nil }
        let texts = AX.find(in: row, text: nil, role: "AXStaticText", depth: 4).map { AX.string($0, "AXValue") ?? AX.label($0) }
        let parts = ([AX.label(row)] + texts).filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Every System Settings window: a pane P8 confirmed (by its sidebar and title, or by its title
    /// where P8 found the sidebar unreadable), nothing refused.
    static func check(_ settings: RunningProcess) throws {
        for window in AX.windows(settings) {
            let title = AX.string(window, "AXTitle") ?? ""
            let sidebar = sidebarSelection(window)
            if isRefused(title) || isRefused(sidebar ?? "") {
                throw Refusal(description: "System Settings shows a pane it never acts in")
            }
            guard let sidebar else {
                guard isAllowed(title: title) else {
                    throw Refusal(
                        description: "System Settings' sidebar selection can't be read, and its title isn't a pane proof P8 confirmed by its title"
                    )
                }
                continue
            }
            guard isAllowed(sidebar: sidebar, title: title) else {
                throw Refusal(description: "System Settings shows a pane outside proof P8's list (\(title))")
            }
        }
    }

    /// The element, its two parents and its children to depth 2 must not name a refused pane (the
    /// sidebar's Privacy & Security row, an "Open Privacy Settings" button).
    static func checkLabels(of element: AXUIElement) throws {
        let around = AX.chain(element, hops: 2) + AX.find(in: element, text: nil, role: nil, depth: 2)
        if around.contains(where: { isRefused(AX.label($0)) }) {
            throw Refusal(description: "that element names a System Settings pane it never acts in")
        }
    }
}

// MARK: - The Dock's tiles

enum Dock {
    struct Tile {
        let element: AXUIElement
        let frame: CGRect
        let hash: String
    }

    /// FNV-1a over the title's UTF-8: tiles are compared without printing his windows' titles.
    static func titleHash(_ title: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in title.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return String(hash, radix: 16)
    }

    /// Every minimized window's tile (AXMinimizedWindowDockItem); an app's own tile never counts.
    static func minimizedTiles() throws -> [Tile] {
        let dock = try Processes.app(Rules.dock)
        return AX.find(in: AX.application(dock), text: nil, role: "AXDockItem", depth: 6).compactMap { item in
            guard AX.string(item, "AXSubrole") == "AXMinimizedWindowDockItem", let frame = AX.frame(item) else {
                return nil
            }
            return Tile(element: item, frame: frame, hash: titleHash(AX.string(item, "AXTitle") ?? ""))
        }
    }

    /// The Dock's bar: the frames of the Dock's AXList elements (its tiles' containers), nil when
    /// AX can't read them. By the window list alone, a point under the Dock's full-display overlay
    /// must lie outside them (`Safety.checkClearOfDockBar`).
    static func barFrames() -> [CGRect]? {
        guard let dock = try? Processes.app(Rules.dock) else { return nil }
        let frames = AX.children(AX.application(dock)).filter { AX.role($0) == "AXList" }.compactMap(AX.frame)
        return frames.isEmpty ? nil : frames
    }

    /// A menu the Dock shows (its own, or a tile's), which it may draw in its full-display overlay
    /// over any point: while one is open, nothing is clicked there by the window list alone
    /// (`Safety.checkClearOfDockBar`). Only menus: the idle Dock's other AX children aren't known
    /// on macOS 27.2, and a rule on them could refuse every such click.
    static func menuOpen() -> Bool {
        guard let dock = try? Processes.app(Rules.dock) else { return true }
        let top = AX.children(AX.application(dock))
        if top.contains(where: { AX.role($0) == "AXMenu" }) { return true }
        return top.filter { AX.role($0) == "AXList" }.flatMap { AX.children($0) }.contains { tile in
            AX.children(tile).contains { AX.role($0) == "AXMenu" }
        }
    }

    /// The hashes a `frame --dock --list` file holds.
    static func listed(_ path: String) throws -> [String] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw Failure(description: "can't read \(path)")
        }
        return text.split(separator: "\n").compactMap { $0.split(separator: "\t").last.map(String.init) }
    }

    /// The tile meant: with --new-since, the one minimized window that appeared since that list
    /// (and, with --dock-title too, titled so); else the one tile with exactly that title.
    static func tile(_ options: Options, title positional: String? = nil) throws -> Tile {
        let tiles = try minimizedTiles()
        let wanted = (options.value("--dock-title") ?? positional).map(titleHash)
        if let since = options.value("--new-since") {
            var before: [String: Int] = [:]
            for hash in try listed(since) { before[hash, default: 0] += 1 }
            var now: [String: Int] = [:]
            for tile in tiles { now[tile.hash, default: 0] += 1 }
            let grown = now.filter { $0.value > (before[$0.key] ?? 0) }
            guard grown.count == 1, let new = grown.first, new.value - (before[new.key] ?? 0) == 1 else {
                throw NotFound(description: "no single new minimized-window tile in the Dock (\(grown.count) titles grew)")
            }
            guard new.value == 1, let tile = tiles.first(where: { $0.hash == new.key }) else {
                throw NotFound(description: "the new tile's title is on \(new.value) tiles: which one is new can't be told")
            }
            if let wanted, wanted != tile.hash {
                throw NotFound(description: "the new tile isn't titled as the window was")
            }
            return tile
        }
        guard let wanted else { throw UsageError(description: "a Dock tile is --new-since <file> or --dock-title <title>") }
        let matches = tiles.filter { $0.hash == wanted }
        guard matches.count == 1, let tile = matches.first else {
            throw NotFound(description: "\(matches.count) minimized-window tiles have that title (one is needed)")
        }
        return tile
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

    /// The frontmost visible window that contains the point, at any level (the screen saver and a
    /// lock shield included); only the window server's own windows and the Dock's full-display
    /// overlay (`Rules.isDockOverlay`) are passed over.
    static func topWindow(at point: CGPoint, in list: [Window]) -> Window? {
        let screens = displays()
        return list.first {
            $0.bounds.contains(point) && $0.alpha > 0.01 && !Rules.windowServer.contains($0.owner)
                && !Rules.isDockOverlay($0, displays: screens)
        }
    }

    /// Windows that count for the safety scans: visible and larger than a few points.
    static func visible(_ list: [Window]) -> [Window] {
        list.filter { $0.alpha > 0.01 && $0.bounds.width * $0.bounds.height > 100 }
    }

    static func session() -> [String: Any] {
        (CGSessionCopyCurrentDictionary() as? [String: Any]) ?? [:]
    }

    /// Locked by the session's own key, or with a loginwindow window on screen (its key may be
    /// missing).
    static func isLocked(_ list: [Window]? = nil) -> Bool {
        if (session()["CGSSessionScreenIsLocked"] as? Bool) ?? false { return true }
        return visible(list ?? windows()).contains { Rules.isLoginWindow(Processes.process($0.pid)) }
    }

    static func isOnConsole() -> Bool { (session()["kCGSSessionOnConsoleKey"] as? Bool) ?? true }

    /// The screen saver shows: an on-screen window of ScreenSaverEngine or legacyScreenSaver (not
    /// the process alone, which may linger).
    static func screenSaverShows(_ list: [Window]? = nil) -> Bool {
        visible(list ?? windows()).contains { Rules.isScreenSaver(Processes.process($0.pid), owner: $0.owner) }
    }

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

/// What lies at a point by AX: the element and its owner.
struct AXHit {
    let element: AXUIElement
    let owner: RunningProcess
}

/// What lies at a point by the window list: the topmost window, its owner, the list it came from,
/// and the Dock's full-display overlay when one lay above the topmost window there (passed over).
struct WindowHit {
    let top: Window
    let owner: RunningProcess
    let list: [Window]
    let dockOverlay: Window?
}

enum Safety {
    /// The sessions' folders, ~/bp-070/<name> of the account's own home.
    static let sessions = ["R", "C", "H", "D3"]

    /// The session's folder: the one above the bin/ this executable runs from, when that is
    /// ~/bp-070/R, C, H or D3 of the account's own home; nil otherwise (`run` refuses then).
    static let folder: String? = {
        guard let home = Account.home, let executable = Processes.path(getpid()) else { return nil }
        let bin = URL(fileURLWithPath: executable).resolvingSymlinksInPath().deletingLastPathComponent()
        let session = bin.deletingLastPathComponent()
        let root = URL(fileURLWithPath: home + "/bp-070").resolvingSymlinksInPath().path
        guard bin.lastPathComponent == "bin", session.deletingLastPathComponent().path == root,
            Safety.sessions.contains(session.lastPathComponent)
        else { return nil }
        return session.path
    }()

    /// The session's folder (`run` refuses everything without one).
    static let home = folder ?? "/var/empty"

    /// Session R's folder, whose ready and day-ended fence every session.
    static let sessionR = (Account.home ?? "/var/empty") + "/bp-070/R"

    static func modified(_ path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    /// The arm window's process as arm.pid records it: its pid and its start time, the first two
    /// fields, so a later process that got the same pid isn't taken for it.
    static func armProcess(in path: String) -> (pid: pid_t, start: Int)? {
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let fields = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard fields.count >= 2, let pid = pid_t(fields[0]), let start = Int(fields[1]) else { return nil }
        return (pid, start)
    }

    /// That process is one of this call's ancestors, started when the file says.
    static func isAncestor(_ arm: (pid: pid_t, start: Int)) -> Bool {
        Processes.ancestors().contains(arm.pid) && Processes.startTime(arm.pid) == arm.start
    }

    /// Session R's arm window (its arm.pid) is an ancestor.
    static func callerIsArm() -> Bool {
        armProcess(in: sessionR + "/arm.pid").map(isAncestor) ?? false
    }

    /// Refuses from Session R's `ready` until a newer day-ended (the logged day), unless Session
    /// R's arm window is an ancestor; and always without a session folder.
    static func checkFence() throws {
        guard folder != nil else {
            throw Refusal(description: "ui runs only from a session's bin/ (~/bp-070/R, C, H or D3)")
        }
        if let readyAt = modified(sessionR + "/ready") {
            let ended = modified(sessionR + "/day-ended").map { $0 > readyAt } ?? false
            if !ended, !callerIsArm() {
                throw Refusal(description: "Session R's ready is up (\(sessionR)/ready): nothing acts until his day-end")
            }
        }
    }

    static func checkSession() throws {
        if Screen.isLocked() { throw Refusal(description: "the screen is locked") }
        if Screen.isLidClosed() { throw Refusal(description: "the lid is closed") }
        if !Screen.isOnConsole() { throw Refusal(description: "the session isn't on the console") }
    }

    /// Every rule that doesn't depend on a point (the reads' rules).
    static func checkAll() throws {
        try checkFence()
        try checkSession()
    }

    /// No refused process, screen saver or lock window on screen (Terminal's own windows aside).
    static func scanWindows(_ list: [Window]) throws {
        for window in Screen.visible(list) {
            let owner = Processes.process(window.pid)
            if Rules.isLoginWindow(owner) { throw Refusal(description: "the screen is locked (loginwindow shows a window)") }
            if Rules.isScreenSaver(owner, owner: window.owner) { throw Refusal(description: "the screen saver shows") }
            if Rules.isTerminal(owner) { continue }
            if Rules.isRefused(owner) {
                throw Refusal(description: "\(owner.publicName) shows a window (a dialog or a prompt)")
            }
        }
    }

    /// An action's rules: every rule above, a Shift, Control or button a killed ui left down
    /// released, and the window scan.
    static func checkAction() throws {
        try checkAll()
        Events.releaseStuck()
        try scanWindows(Screen.windows())
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

    /// The element at the point, by AX (nil when AX finds nothing); never a refused process's.
    static func axHit(_ point: CGPoint) throws -> AXHit? {
        guard let element = AX.element(at: point), let pid = AX.pid(element) else { return nil }
        let owner = Processes.process(pid)
        if Rules.isRefused(owner) { throw Refusal(description: "\(owner.publicName) is at that point: never acted on") }
        return AXHit(element: element, owner: owner)
    }

    /// The point by a fresh window list: no refused process, screen saver or lock window anywhere
    /// under it (Terminal's only as the topmost), then the topmost window, the Dock's full-display
    /// overlay passed over (`Rules.isDockOverlay`). With `skippingHosts`, the topmost that isn't a
    /// widget host's (a dragged widget's own image is one).
    static func windowHit(_ point: CGPoint, skippingHosts: Bool = false) throws -> WindowHit {
        let list = Screen.windows()
        for window in list where window.bounds.contains(point) && window.alpha > 0.01 {
            let owner = Processes.process(window.pid)
            if Rules.isTerminal(owner) { continue }
            if Rules.isRefused(owner) || Rules.isScreenSaver(owner, owner: window.owner) {
                throw Refusal(description: "\(owner.publicName) has a window at that point: never acted on")
            }
        }
        let hosts: Set<String> = skippingHosts ? Rules.widgetHosts() : []
        let displays = Screen.displays()
        var overlay: Window?
        let found = list.first { window in
            guard window.bounds.contains(point) else { return false }
            if Rules.isDockOverlay(window, displays: displays) {
                if overlay == nil { overlay = window }
                return false
            }
            guard window.alpha > 0.01, !Rules.windowServer.contains(window.owner) else { return false }
            return !skippingHosts || !hosts.contains(Processes.process(window.pid).bundle)
        }
        guard let top = found else {
            throw Refusal(description: "nothing to hit-test at (\(Int(point.x)), \(Int(point.y)))")
        }
        let owner = Processes.process(top.pid)
        if Rules.isRefused(owner) { throw Refusal(description: "\(owner.publicName) is at that point: never acted on") }
        return WindowHit(top: top, owner: owner, list: list, dockOverlay: overlay)
    }

    /// Just before a posted button, wheel or move event: a fresh window list still shows `expected`
    /// as the topmost window at the point (its ID and its process), with nothing refused, no
    /// screen saver and no lock window there, the session unlocked, the lid open and no fence up.
    /// The window list only, so the event follows within milliseconds.
    static func recheck(_ point: CGPoint, _ expected: Window, skippingHosts: Bool = false) throws {
        try checkFence()
        if (Screen.session()["CGSSessionScreenIsLocked"] as? Bool) ?? false {
            throw Refusal(description: "the screen locked before the event")
        }
        if Screen.isLidClosed() { throw Refusal(description: "the lid closed before the event") }
        let hit = try windowHit(point, skippingHosts: skippingHosts)
        let shield = Screen.visible(hit.list).first { window in
            window.owner == "loginwindow" || Rules.screenSaverNames.contains { window.owner.hasPrefix($0) }
        }
        if let shield { throw Refusal(description: "\(shield.owner) showed a window before the event") }
        guard hit.top.id == expected.id, hit.top.pid == expected.pid else {
            throw Refusal(
                description: "the topmost window at (\(Int(point.x)), \(Int(point.y))) changed since its check (\(expected.id) is now \(hit.top.id), \(hit.owner.publicName))"
            )
        }
    }

    /// A click, move or scroll: what lies at the point must be what the caller expects. AX first
    /// (System Settings' pane check walks its windows for about a second), the window list last,
    /// so the topmost window it returns, which `recheck` compares before each event, is the newest.
    static func checkPoint(_ point: CGPoint, expect: Expectation, byAX: Bool, windowID: UInt32?) throws -> Window {
        try checkCorners(point)
        var ax: AXHit?
        if byAX { ax = try axHit(point) }
        try checkElement(ax, at: point, expect: expect, byAX: byAX)
        let hit = try windowHit(point)
        if let windowID, hit.top.id != windowID {
            throw Refusal(description: "the topmost window there is \(hit.top.id), not window \(windowID)")
        }
        try checkTop(hit, at: point, expect: expect, byAX: byAX)
        return hit.top
    }

    /// The AX half of a point's rules: the element there and its owner.
    static func checkElement(_ ax: AXHit?, at point: CGPoint, expect: Expectation, byAX: Bool) throws {
        switch expect {
        case .app(let bundle):
            guard Rules.isPointApproved(bundle) else { throw Refusal(description: "\(bundle) isn't on the approved list") }
            let isHost = Rules.widgetHosts().contains(bundle)
            guard byAX else {
                if [Rules.settings, Rules.controlCenter, Rules.textEdit, Rules.xcode].contains(bundle) {
                    throw Refusal(description: "System Settings, Control Center, TextEdit and Xcode need the AX hit test")
                }
                if isHost, !Rules.isInsideWidget(point) {
                    throw Refusal(description: "not inside a recorded BatteryPulse widget frame")
                }
                return
            }
            guard let ax, ax.owner.bundle == bundle else {
                throw Refusal(description: "AX finds \(ax?.owner.publicName ?? "nothing") there, not the expected app")
            }
            if bundle == Rules.settings {
                try Panes.check(ax.owner)
                try Panes.checkLabels(of: ax.element)
            }
            if bundle == Rules.controlCenter, !AX.hasIdentifier(ax.element, Rules.clockIdentifier, hops: 3) {
                throw Refusal(description: "Control Center is approved for its clock alone")
            }
            try OwnWindows.check(OwnWindows.window(of: ax.element), of: ax.owner)
            // A widget host also holds his other widgets, the Notification Center panel and his
            // banners: only an element inside a BatteryPulse-labelled one, whatever frame was recorded.
            if isHost, !AX.isInsideBatteryPulse(ax.element) {
                throw Refusal(description: "not a BatteryPulse widget (no BatteryPulse label in the AX chain)")
            }
        case .banner:
            guard byAX, let ax, ax.owner.bundle == Rules.notificationCenter, AX.isInsideBatteryPulse(ax.element) else {
                throw Refusal(description: "BatteryPulse's banner isn't at that point")
            }
        case .desktop:
            guard byAX else { throw Refusal(description: "the desktop needs the AX hit test") }
            guard let ax else {
                throw Refusal(description: "AX finds nothing there: a file's icon can't be told from bare desktop")
            }
            guard Rules.isDesktopOwner(ax.owner) else {
                throw Refusal(description: "AX finds \(ax.owner.publicName) there, not the desktop")
            }
            if AX.isIconLike(ax.element) {
                throw Refusal(description: "an icon, a control or a menu is at that point (\(AX.role(ax.element)))")
            }
        case .dockTile(let tile):
            guard byAX else { throw Refusal(description: "a Dock tile needs the AX hit test") }
            guard let ax, ax.owner.bundle == Rules.dock, AX.isOrIsInside(ax.element, tile, hops: 2) else {
                throw Refusal(description: "the Dock tile found isn't what lies at its centre")
            }
        }
    }

    /// The window-list half of a point's rules: the topmost window there and its owner.
    static func checkTop(_ hit: WindowHit, at point: CGPoint, expect: Expectation, byAX: Bool) throws {
        switch expect {
        case .app(let bundle):
            guard hit.owner.bundle == bundle else {
                throw Refusal(description: "\(hit.owner.publicName) has the topmost window there, not the expected app")
            }
            // By the window list alone, a point under the Dock's overlay must be off its bar, which
            // the overlay may draw (AX finds the Dock there otherwise).
            if !byAX, hit.dockOverlay != nil { try checkClearOfDockBar(point) }
            // By the window list alone a recorded frame counts only at the desktop's widget layer,
            // below level 0: the Notification Center panel and a banner sit above it.
            if !byAX, Rules.widgetHosts().contains(bundle), hit.top.layer >= 0 {
                throw Refusal(
                    description: "by the window list alone, a widget host counts only at the desktop's widget layer (layer \(hit.top.layer) is its panel or a banner)"
                )
            }
        case .banner:
            guard hit.owner.bundle == Rules.notificationCenter else {
                throw Refusal(description: "the banner isn't the topmost window at that point")
            }
        case .desktop:
            guard Rules.isDesktopWindow(hit.top, hit.owner) || Rules.isRevealDesktopWindow(hit.top, hit.owner) else {
                throw Refusal(
                    description: "the topmost window there isn't the desktop (\(hit.owner.publicName), layer \(hit.top.layer))")
            }
            try checkNoMenuBar(point, hit.list)
        case .dockTile:
            // The tile may be drawn in the Dock's full-display overlay itself, which the hit test
            // passes over: then the overlay must lie over the point, and AX found the tile there
            // (checkElement).
            guard hit.owner.bundle == Rules.dock || hit.dockOverlay != nil else {
                throw Refusal(description: "the Dock isn't the topmost window at the tile's centre")
            }
        }
    }

    /// A point by the window list alone, under the Dock's full-display overlay: outside the Dock's
    /// bar by its AX frames (8 points of margin), and refused when they can't be read or while the
    /// Dock shows a menu (`Dock.menuOpen`), which the overlay may draw over the point.
    static func checkClearOfDockBar(_ point: CGPoint) throws {
        if Dock.menuOpen() {
            throw Refusal(description: "the Dock shows a menu, which its full-display window may draw over that point: nothing is clicked there by the window list alone")
        }
        guard let bars = Dock.barFrames() else {
            throw Refusal(description: "the Dock's bar can't be located under its full-display window: nothing is clicked there by the window list alone")
        }
        if bars.contains(where: { $0.insetBy(dx: -8, dy: -8).contains(point) }) {
            throw Refusal(description: "the Dock's bar is at that point")
        }
    }

    /// The menu bar isn't at the point: the topmost-window rule passes over the window server's
    /// windows, so Finder's desktop window counts as topmost under the whole menu bar. Its strip is
    /// the top 44 points of a display (the M5's menu bar is the notch's height, about 37), or a
    /// window server window above level 0 along a display's top edge, at most 60 points high (the
    /// menu bar's backdrop). Not any window server window: the cursor's own contains the pointer
    /// wherever it rests, so a second click on the same desktop spot would always be refused.
    static func checkNoMenuBar(_ point: CGPoint, _ list: [Window]) throws {
        let displays = Screen.displays()
        let inStrip = displays.contains { $0.contains(point) && point.y < $0.minY + 44 }
        let underBar = list.contains { window in
            Rules.windowServer.contains(window.owner) && window.layer > 0 && window.bounds.contains(point)
                && window.bounds.height <= 60 && displays.contains { abs($0.minY - window.bounds.minY) < 1 }
        }
        if inStrip || underBar {
            throw Refusal(description: "the menu bar is at that point, not the desktop")
        }
    }

    /// A drag's start: a BatteryPulse widget in its host (the gallery's or a placed one), never his
    /// own widgets or a file. Returns the topmost window, which `recheck` compares before the down.
    static func checkDragFrom(_ point: CGPoint) throws -> Window {
        let hosts = Rules.widgetHosts()
        let ax = try axHit(point)
        guard let ax, hosts.contains(ax.owner.bundle), AX.isInsideBatteryPulse(ax.element) else {
            throw Refusal(
                description: "a drag starts only at a BatteryPulse widget in its host (AX finds \(ax?.owner.publicName ?? "nothing") there)"
            )
        }
        let hit = try windowHit(point)
        guard hosts.contains(hit.owner.bundle) else {
            throw Refusal(description: "a drag starts only at a widget in its host (\(hit.owner.publicName) is there)")
        }
        return hit.top
    }

    /// A drag's end: the widget layer, or the bare desktop; never an icon, a folder, the menu bar or
    /// the Dock. Returns the topmost window that isn't a widget host's, which `recheck` compares
    /// before the final up (the dragged widget's image is the host's).
    static func checkDragTo(_ point: CGPoint) throws -> Window {
        let hosts = Rules.widgetHosts()
        guard let ax = try axHit(point) else {
            throw Refusal(description: "AX finds nothing at the drag's end: an icon can't be told from bare desktop")
        }
        if ax.owner.bundle == Rules.dock { throw Refusal(description: "a drag never ends on the Dock") }
        guard hosts.contains(ax.owner.bundle) || Rules.isDesktopOwner(ax.owner) else {
            throw Refusal(description: "AX finds \(ax.owner.publicName) at the drag's end")
        }
        if Rules.isDesktopOwner(ax.owner), AX.isIconLike(ax.element) {
            throw Refusal(description: "an icon, a control or a menu is at the drag's end (\(AX.role(ax.element)))")
        }
        let hit = try windowHit(point)
        guard hosts.contains(hit.owner.bundle) || Rules.isDesktopWindow(hit.top, hit.owner) else {
            throw Refusal(description: "a drag ends only on the desktop or the widget layer (\(hit.owner.publicName) is there)")
        }
        try checkNoMenuBar(point, hit.list)
        return try windowHit(point, skippingHosts: true).top
    }

    /// An app an AX action may target; System Settings only on a confirmed pane (`quit` skips that:
    /// its Quit menu item touches no pane).
    static func checkTarget(_ process: RunningProcess, panes: Bool = true) throws {
        if Rules.isRefused(process) { throw Refusal(description: "\(process.publicName) is never acted on") }
        guard Rules.targetBundles.contains(process.bundle) else {
            throw Refusal(description: "\(process.publicName) isn't a target (Finder, the Dock and Control Center never are)")
        }
        if panes, process.bundle == Rules.settings { try Panes.check(process) }
    }

    /// `guard`: every action's rule, now, plus System Settings' panes whenever it shows a window.
    static func checkNow() throws {
        try checkAll()
        Events.releaseStuck()
        let list = Screen.windows()
        try scanWindows(list)
        let shown = Set(Screen.visible(list).filter { $0.layer == 0 }.map(\.pid))
        if let settings = try? Processes.app(Rules.settings), shown.contains(settings.pid) {
            try Panes.check(settings)
        }
    }
}

extension Rules {
    /// Hot corner actions it keeps away from: Start Screen Saver, Put Display to Sleep, Lock Screen.
    static let dangerousCorners: Set<Int> = [5, 10, 13]
    static let cornerMargin: CGFloat = 20
}

// MARK: - Posted events

/// SIGINT, SIGTERM and SIGHUP (his Esc, a tool's timeout) wait while a button or a modifier is
/// down, and arrive once it is back up; a `defer` doesn't run on a signal. SIGKILL can't wait:
/// `Events.releaseStuck` puts back what it leaves.
enum Signals {
    /// Darwin's sigset_t is a bit mask: signal n is bit n - 1 (sigaddset is a macro on arm64).
    static let mask: sigset_t = [SIGINT, SIGTERM, SIGHUP].reduce(sigset_t(0)) { $0 | (sigset_t(1) << ($1 - 1)) }

    static func hold() {
        var set = mask
        sigprocmask(SIG_BLOCK, &set, nil)
    }

    static func release() {
        var set = mask
        sigprocmask(SIG_UNBLOCK, &set, nil)
    }
}

enum Events {
    static func tap(_ options: Options) -> CGEventTapLocation { options.value("--tap").map(location) ?? defaultTap() }

    /// Proof P6's tap (ui-tap), else the HID tap.
    static func defaultTap() -> CGEventTapLocation {
        location(Files.text("ui-tap").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func location(_ name: String) -> CGEventTapLocation { name == "session" ? .cgSessionEventTap : .cghidEventTap }

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

    /// A click; `recheck` runs immediately before each down (both of a double click), and a refusal
    /// there ends the click with nothing pressed.
    static func click(
        _ point: CGPoint, modifier flags: CGEventFlags, double: Bool, tap: CGEventTapLocation,
        recheck: () throws -> Void
    ) throws {
        Signals.hold()
        defer { Signals.release() }
        if !flags.isEmpty {
            try modifier(flags, down: true, tap: tap)
        }
        // The modifier comes back up however the click ends, so Shift or Control never stays down.
        defer { if !flags.isEmpty { try? modifier(flags, down: false, tap: tap) } }
        if !flags.isEmpty { pause(0.08) }
        try mouse(.mouseMoved, point, flags: flags, clicks: 0, tap: tap)
        pause(0.08)
        for count in 1...(double ? 2 : 1) {
            try recheck()
            try mouse(.leftMouseDown, point, flags: flags, clicks: count, tap: tap)
            pause(0.05)
            try mouse(.leftMouseUp, point, flags: flags, clicks: count, tap: tap)
            pause(0.08)
        }
        if !flags.isEmpty { pause(0.08) }
    }

    /// A Shift, Control or left button that the session's event state shows down and the hardware's
    /// doesn't (a ui killed between its down and its up): released, the button at the pointer.
    static func releaseStuck() {
        let tap = defaultTap()
        let posted = CGEventSource.flagsState(.combinedSessionState)
        let held = CGEventSource.flagsState(.hidSystemState)
        for flag in [CGEventFlags.maskShift, .maskControl] where posted.contains(flag) && !held.contains(flag) {
            try? modifier(flag, down: false, tap: tap)
        }
        if CGEventSource.buttonState(.combinedSessionState, button: .left),
            !CGEventSource.buttonState(.hidSystemState, button: .left)
        {
            try? mouse(.leftMouseUp, current(), flags: [], clicks: 1, tap: tap)
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
            "--depth", "--app", "--allow-cover", "--ax", "--within", "--expect", "--new-since", "--dock-title",
        ]
        let takesFour: Set<String> = ["--inside"]
        let switches: Set<String> = [
            "--shift", "--control", "--double", "--here", "--probe", "--main", "--minimize-button", "--status-item",
            "--cg-only", "--dock", "--list", "--widgets",
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

    /// A point command's --window: a CGWindowID the topmost window there must have.
    func windowID() throws -> UInt32? {
        guard let text = values["--window"] else { return nil }
        guard let id = UInt32(text) else { throw UsageError(description: "--window takes a CGWindowID here") }
        return id
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

    /// What a point command is aimed at (`--expect`), which every click, move and scroll names.
    static func expectation(_ options: Options) throws -> Expectation {
        guard let value = options.value("--expect") else {
            throw UsageError(description: "name what lies at the point: --expect <app | bundle | desktop | dock-tile>")
        }
        switch value {
        case "desktop": return .desktop
        case "dock-tile": throw UsageError(description: "--expect dock-tile is a click's, and takes no point")
        default: return .app(Rules.bundle(for: value))
        }
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
        try Safety.checkAction()
        let flags = try modifier(options)
        let double = options.has("--double")
        let byAX = !options.has("--cg-only")
        let point: CGPoint
        let expect: Expectation
        if let appName = options.value("--ax") {
            let process = try Processes.app(appName)
            if Rules.isRefused(process) || !Rules.isPointApproved(process.bundle) {
                throw Refusal(description: "\(process.publicName) isn't on the approved list")
            }
            guard let text = options.words.dropFirst().first else {
                throw UsageError(description: "click --ax <app> <text>")
            }
            let element: AXUIElement
            if process.bundle == Rules.controlCenter, text == "clock" {
                // The clock's label is the time; its identifier is fixed (it opens Notification Center).
                guard
                    let clock = AX.find(in: AX.application(process), text: nil, role: nil, depth: 8).first(where: {
                        AX.string($0, "AXIdentifier") == Rules.clockIdentifier
                    })
                else { throw NotFound(description: "Control Center's clock isn't in AX") }
                element = clock
            } else {
                element = try match(process, text, options)
            }
            guard let frame = AX.frame(element) else { throw Failure(description: "the element has no frame") }
            point = CGPoint(x: frame.midX, y: frame.midY)
            expect = .app(process.bundle)
        } else if options.value("--expect") == "dock-tile" {
            let tile = try Dock.tile(options)
            point = CGPoint(x: tile.frame.midX, y: tile.frame.midY)
            expect = .dockTile(tile.element)
        } else {
            point = try options.point(at: 1)
            expect = try expectation(options)
        }
        if case .desktop = expect, double || !flags.isEmpty {
            throw Refusal(description: "the desktop takes one plain click (a double click opens, a modifier selects)")
        }
        if case .dockTile = expect, double { throw Refusal(description: "a Dock tile takes a single click") }
        let top = try Safety.checkPoint(point, expect: expect, byAX: byAX, windowID: try options.windowID())
        if options.has("--probe") {
            print("would click \(Int(point.x)) \(Int(point.y)): the point holds")
            return
        }
        try Events.click(point, modifier: flags, double: double, tap: Events.tap(options)) {
            try Safety.recheck(point, top)
        }
        print("clicked \(Int(point.x)) \(Int(point.y))")
    }

    static func move(_ options: Options) throws {
        try Safety.checkAction()
        // A 0-pixel move where the pointer already is clicks nothing: no hit test, so it works over
        // Terminal too (proof P6).
        let point: CGPoint
        if options.has("--here") {
            point = Events.current()
        } else {
            point = try options.point(at: 1)
            let top = try Safety.checkPoint(
                point, expect: try expectation(options), byAX: !options.has("--cg-only"), windowID: try options.windowID())
            try Safety.recheck(point, top)
        }
        try Events.mouse(.mouseMoved, point, flags: [], clicks: 0, tap: Events.tap(options))
        print("moved to \(Int(point.x)) \(Int(point.y))")
    }

    static func drag(_ options: Options) throws {
        try Safety.checkAction()
        let from = try options.point(at: 1)
        let to = try options.point(at: 3)
        let steps = max(2, Int(try options.number("--steps", default: 30)))
        let seconds = max(0.2, try options.number("--seconds", default: 2))
        let points = (0...steps).map { step -> CGPoint in
            let t = CGFloat(step) / CGFloat(steps)
            return CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
        }
        for point in points { try Safety.checkCorners(point) }
        let fromTop = try Safety.checkDragFrom(from)
        let toTop = try Safety.checkDragTo(to)
        let tap = Events.tap(options)
        Signals.hold()
        defer { Signals.release() }
        try Events.mouse(.mouseMoved, from, flags: [], clicks: 0, tap: tap)
        Events.pause(0.1)
        try Safety.recheck(from, fromTop)
        try Events.mouse(.leftMouseDown, from, flags: [], clicks: 1, tap: tap)
        // The button comes back up where the drag got to, however it ends.
        var reached = from
        var released = false
        defer { if !released { try? Events.mouse(.leftMouseUp, reached, flags: [], clicks: 1, tap: tap) } }
        // A hold before the first step, so a widget in the gallery lifts.
        Events.pause(0.4)
        for point in points.dropFirst() {
            try Events.mouse(.leftMouseDragged, point, flags: [], clicks: 1, tap: tap)
            reached = point
            Events.pause(seconds / Double(steps))
        }
        Events.pause(0.3)
        do {
            try Safety.recheck(to, toTop, skippingHosts: true)
        } catch {
            // Something else came to the drop point: the widget goes back where it came from, and
            // the button comes up there.
            for point in points.reversed().dropFirst() {
                try? Events.mouse(.leftMouseDragged, point, flags: [], clicks: 1, tap: tap)
                reached = point
                Events.pause(0.01)
            }
            try? Events.mouse(.leftMouseUp, from, flags: [], clicks: 1, tap: tap)
            released = true
            throw error
        }
        try Events.mouse(.leftMouseUp, to, flags: [], clicks: 1, tap: tap)
        released = true
        print("dragged \(Int(from.x)) \(Int(from.y)) to \(Int(to.x)) \(Int(to.y)) in \(steps) steps")
    }

    static func scroll(_ options: Options) throws {
        try Safety.checkAction()
        let point = try options.point(at: 1)
        guard options.words.count > 3, let lines = Int32(options.words[3]) else {
            throw UsageError(description: "scroll <point> <lines>")
        }
        let top = try Safety.checkPoint(
            point, expect: try expectation(options), byAX: !options.has("--cg-only"), windowID: try options.windowID())
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
        try Safety.recheck(point, top)
        event.post(tap: tap)
        print("scrolled \(lines) lines at \(Int(point.x)) \(Int(point.y))")
    }

    static func press(_ options: Options) throws {
        try Safety.checkAction()
        let process = try appArgument(options, 1)
        try Safety.checkTarget(process)
        let inSettings = process.bundle == Rules.settings
        if options.has("--status-item") {
            guard process.bundle == Rules.batteryPulse else {
                throw UsageError(description: "press --status-item is BatteryPulse's alone")
            }
            try AX.perform(statusItem(process), "AXPress")
            print("pressed BatteryPulse's menu bar item")
            return
        }
        if let character = options.value("--menu-cmd") {
            // A menu command acts on the front window.
            try OwnWindows.check(AX.frontWindow(process), of: process)
            let item = try menuItem(process, command: character)
            if inSettings { try Panes.checkLabels(of: item) }
            try AX.perform(item, "AXPress")
            print("pressed the menu item with Command-\(character) in \(process.publicName)")
            return
        }
        guard options.words.count > 2 else { throw UsageError(description: "press <app> <text>") }
        let matched = try match(process, options.words[2], options)
        try OwnWindows.check(OwnWindows.window(of: matched), of: process)
        var element = matched
        let action = options.value("--action") ?? "AXPress"
        // A label inside a button: press the nearest ancestor that can.
        var hops = 0
        while !AX.actions(element).contains(action), hops < 4, let parent = AX.parent(element) {
            element = parent
            hops += 1
        }
        if inSettings {
            try Panes.checkLabels(of: matched)
            try Panes.checkLabels(of: element)
        }
        try AX.perform(element, action)
        print("\(action) on \(AX.role(element)) in \(process.publicName)")
    }

    /// BatteryPulse's menu bar item: the first child of the app's AXExtrasMenuBar (macOS 27.2 lists
    /// no window for it in CGWindowList, 0.6.2's P11).
    static func statusItem(_ process: RunningProcess) throws -> AXUIElement {
        guard let bar = AX.element(AX.attribute(AX.application(process), "AXExtrasMenuBar")),
            let item = AX.children(bar).first
        else { throw NotFound(description: "BatteryPulse has no menu bar item in AX (AXExtrasMenuBar)") }
        return item
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
        try Safety.checkAction()
        let process = try appArgument(options, 1)
        try Safety.checkTarget(process)
        guard options.words.count > 2 else { throw UsageError(description: "select-row <app> <text>") }
        let matched = try match(process, options.words[2], options)
        try OwnWindows.check(OwnWindows.window(of: matched), of: process)
        var element = matched
        var hops = 0
        while !AX.role(element).hasPrefix("AXRow"), hops < 5, let parent = AX.parent(element) {
            element = parent
            hops += 1
        }
        guard AX.role(element).hasPrefix("AXRow") else { throw NotFound(description: "the match isn't in a row") }
        if process.bundle == Rules.settings {
            try Panes.checkLabels(of: matched)
            try Panes.checkLabels(of: element)
        }
        try AX.set(element, "AXSelected", NSNumber(value: true))
        print("selected the row")
    }

    /// The --window window (else the main one); in TextEdit and Xcode only the session's own.
    static func window(_ options: Options, _ process: RunningProcess) throws -> AXUIElement {
        let target = try AX.window(process, title: options.value("--window"))
        try OwnWindows.check(target, of: process)
        return target
    }

    static func minimize(_ options: Options) throws {
        try Safety.checkAction()
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
        try Safety.checkAction()
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
        try Safety.checkAction()
        let process = try appArgument(options, 1)
        // Terminal's windows go in the left third (§6 "Places"): moving a window clicks nothing in
        // it, so Terminal may be placed, though never clicked or pressed.
        if process.bundle != Rules.terminal { try Safety.checkTarget(process) }
        let numbers = options.words.dropFirst(2).compactMap(Double.init)
        guard numbers.count == 2 || numbers.count == 4 else {
            throw UsageError(description: "position <app> <x> <y> [<w> <h>]")
        }
        let target = try window(options, process)
        var origin = CGPoint(x: numbers[0], y: numbers[1])
        guard let place = AXValueCreate(.cgPoint, &origin) else { throw Failure(description: "can't make a point") }
        // The origin first, so the size isn't clamped at the old place; then the origin again, in
        // case the size moved it.
        try AX.set(target, "AXPosition", place)
        if numbers.count == 4 {
            var size = CGSize(width: numbers[2], height: numbers[3])
            guard let extent = AXValueCreate(.cgSize, &size) else { throw Failure(description: "can't make a size") }
            try AX.set(target, "AXSize", extent)
            try AX.set(target, "AXPosition", place)
        }
        print("\(process.publicName)'s window at \(AX.frame(target).map(describe) ?? "unknown")")
    }

    /// An AX press on the named window's own close button (TextEdit's cover, when TextEdit runs
    /// for him too and isn't the session's to quit).
    static func close(_ options: Options) throws {
        try Safety.checkAction()
        let process = try appArgument(options, 1)
        try Safety.checkTarget(process)
        guard options.value("--window") != nil else { throw UsageError(description: "close <app> --window <title>") }
        let target = try window(options, process)
        guard let button = AX.element(AX.attribute(target, "AXCloseButton")) else {
            throw NotFound(description: "the window has no close button")
        }
        try AX.perform(button, "AXPress")
        print("closed the window in \(process.publicName)")
    }

    static func banner(_ options: Options) throws {
        try Safety.checkAction()
        guard options.words.count > 1 else { throw UsageError(description: "banner <text>") }
        let text = options.words[1]
        let seconds = try options.number("--seconds", default: 10)
        let start = Date()
        var center = try? Processes.app(Rules.notificationCenter)
        var others = 0
        while Date().timeIntervalSince(start) < seconds {
            if center == nil { center = try? Processes.app(Rules.notificationCenter) }
            if let center {
                let found = AX.find(in: AX.application(center), text: text, role: nil, depth: 14)
                let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                if options.has("--probe"), let element = found.first {
                    print("banner found after \(elapsed) ms: \(AX.role(element))")
                    return
                }
                // Pressed only inside a BatteryPulse banner: his other notifications and Notification
                // Center's own buttons (Clear All) never are.
                others = found.count
                if var element = found.first(where: AX.isInsideBatteryPulse) {
                    var hops = 0
                    while !AX.actions(element).contains("AXPress"), hops < 4, let parent = AX.parent(element) {
                        element = parent
                        hops += 1
                    }
                    // A button inside the banner (Close, Clear, Options) isn't the banner itself.
                    let role = AX.string(element, "AXRole") ?? ""
                    if ["AXButton", "AXMenuButton", "AXCheckBox", "AXPopUpButton"].contains(role),
                        !AX.isBatteryPulseLabelled(element)
                    {
                        throw Refusal(description: "that text is on a button of the banner (\(AX.role(element))), not the banner")
                    }
                    if AX.actions(element).contains("AXPress") {
                        try AX.perform(element, "AXPress")
                        print("banner found after \(elapsed) ms; pressed")
                    } else if let frame = AX.frame(element) {
                        let point = CGPoint(x: frame.midX, y: frame.midY)
                        let top = try Safety.checkPoint(point, expect: .banner, byAX: true, windowID: nil)
                        try Events.click(point, modifier: [], double: false, tap: Events.tap(options)) {
                            try Safety.recheck(point, top)
                        }
                        print("banner found after \(elapsed) ms; clicked at its centre")
                    } else {
                        throw Failure(description: "the banner can't be pressed or clicked")
                    }
                    return
                }
            }
            Events.pause(0.25)
        }
        throw NotFound(
            description: "no BatteryPulse banner matching \(text) within \(Int(seconds)) s (\(others) matches elsewhere, never pressed)")
    }

    static func quit(_ options: Options) throws {
        try Safety.checkAction()
        let process = try appArgument(options, 1)
        try Safety.checkTarget(process, panes: false)
        // His own running copy of an app is never quit: only BatteryPulse, and a process the script
        // opened (launched.tsv: "<app>\t<pid>").
        let launched = Files.text("launched.tsv").split(separator: "\n").compactMap { line in
            line.split(separator: "\t").last.flatMap { pid_t(String($0)) }
        }
        guard process.bundle == Rules.batteryPulse || launched.contains(process.pid) else {
            throw Refusal(description: "\(process.publicName) wasn't opened by the script (launched.tsv): it is never quit")
        }
        try AX.perform(try menuItem(process, command: "Q"), "AXPress")
        print("pressed Quit in \(process.publicName)")
    }

    static func frame(_ options: Options) throws {
        try Safety.checkAll()
        if options.has("--widgets") {
            try widgetFrames()
            return
        }
        if options.has("--status-item") {
            let item = try statusItem(Processes.app(Rules.batteryPulse))
            guard let rect = AX.frame(item) else { throw Failure(description: "BatteryPulse's menu bar item has no frame") }
            print(describe(rect))
            return
        }
        if options.has("--dock") {
            if options.has("--list") {
                for tile in try Dock.minimizedTiles() { print("\(describe(tile.frame))\t\(tile.hash)") }
                return
            }
            let tile = try Dock.tile(options, title: options.words.dropFirst().first)
            print("\(describe(tile.frame)) \(AX.role(tile.element))")
            return
        }
        let process = try readTarget(options)
        let rect: CGRect?
        if let text = options.value("--match") {
            let matched = try match(process, text, options)
            try OwnWindows.check(OwnWindows.window(of: matched), of: process)
            rect = AX.frame(matched)
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

    /// The frames of the widget hosts' elements labelled BatteryPulse, on screen now (the desktop's
    /// widgets, or Notification Center's while it is open), each once and at least 20 points wide
    /// and high; an element inside another one listed is left out. Frames only: his other widgets
    /// and their labels are never read out.
    static func widgetFrames() throws {
        let hosts = Rules.widgetHosts()
        let displays = Screen.displays()
        var frames: [CGRect] = []
        for pid in Processes.all() {
            let process = Processes.process(pid)
            guard hosts.contains(process.bundle) else { continue }
            for element in AX.find(in: AX.application(process), text: nil, role: nil, depth: 14)
            where AX.isBatteryPulseLabelled(element) {
                guard let rect = AX.frame(element), rect.width >= 20, rect.height >= 20,
                    displays.contains(where: { $0.intersects(rect) })
                else { continue }
                frames.append(rect)
            }
        }
        let outer = frames.filter { rect in
            !frames.contains { other in other != rect && other.contains(rect) }
        }
        var printed: [CGRect] = []
        for rect in outer where !printed.contains(rect) {
            printed.append(rect)
            print(describe(rect))
        }
        if printed.isEmpty { throw NotFound(description: "no BatteryPulse-labelled widget element on screen") }
    }

    /// The focused (else main) window's title of BatteryPulse or System Settings (a pane's name);
    /// another app's titles are his documents' names.
    static func title(_ options: Options) throws {
        try Safety.checkAll()
        let process = try readTarget(options)
        guard process.bundle == Rules.batteryPulse || process.bundle == Rules.settings else {
            throw Refusal(description: "only BatteryPulse's and System Settings' titles are read")
        }
        guard let window = AX.frontWindow(process) else { throw NotFound(description: "\(process.publicName) has no window") }
        print("title: \(AX.string(window, "AXTitle") ?? "")")
    }

    /// System Settings' front window: the sidebar's selected row, the title, and with --expect
    /// whether both are that pane's (proof P8).
    static func paneState(_ options: Options) throws {
        try Safety.checkAll()
        let settings = try Processes.app(Rules.settings)
        guard let window = AX.frontWindow(settings) else { throw NotFound(description: "System Settings has no window") }
        let title = AX.string(window, "AXTitle") ?? ""
        let sidebar = Panes.sidebarSelection(window)
        let clean = { (text: String) in text.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
        var match = "-"
        if let name = options.value("--expect") {
            guard Panes.expected[name] != nil else { throw UsageError(description: "no pane \(name) in proof P8's list") }
            match = Panes.matches(name, title: title) && !Panes.isRefused(sidebar ?? "") ? "yes" : "no"
        }
        print("sidebar=\(sidebar.map(clean) ?? "-")\ttitle=\(clean(title))\tmatch=\(match)")
    }

    static func hit(_ options: Options) throws {
        try Safety.checkAll()
        let point = try options.point(at: 1)
        guard let found = AX.element(at: point), let pid = AX.pid(found) else {
            throw NotFound(description: "no element at (\(Int(point.x)), \(Int(point.y)))")
        }
        let owner = Processes.process(pid)
        print("process: \(owner.publicName) (\(owner.isPublic ? owner.bundle : "-"), pid \(pid))")
        if let window = Screen.topWindow(at: point, in: Screen.windows()) {
            print("top window: \(window.id), owner \(Processes.process(window.pid).publicName), layer \(window.layer)")
        }
        guard owner.isPublic else { return }
        // Labels only inside BatteryPulse: its own elements, or from the hit element up to the first
        // element labelled BatteryPulse (a widget's container); above it, roles and frames only.
        let chain = AX.chain(found, hops: 11)
        let own = owner.bundle == Rules.batteryPulse
        let labelled = chain.firstIndex(where: AX.isBatteryPulseLabelled)
        print("batterypulse_label: \(own || labelled != nil ? "yes" : "no")")
        for (level, item) in chain.enumerated() {
            let shows = own || (labelled.map { level <= $0 } ?? false)
            let frame = AX.frame(item).map(describe) ?? "-"
            print(
                "\(String(repeating: "  ", count: level))\(AX.role(item)) \"\(shows ? AX.label(item) : "-")\" frame \(frame) actions \(AX.actions(item).joined(separator: ","))"
            )
        }
    }

    static func tree(_ options: Options) throws {
        try Safety.checkAll()
        let process = try readTarget(options)
        let depth = Int(try options.number("--depth", default: 12))
        let inside = try options.rect("--inside")
        let text = options.value("--match")
        if process.bundle == Rules.settings {
            guard let text else { throw Refusal(description: "System Settings' tree is read only as --match <text>") }
            let count = AX.find(in: AX.application(process), text: text, role: nil, depth: depth + 10).count
            print("match \(text): \(count > 0 ? "found" : "not found") (\(count))")
            return
        }
        let own = process.bundle == Rules.batteryPulse
        let host = Rules.widgetHosts().contains(process.bundle)
        if host {
            // A widget host holds his other widgets and his notifications: only a recorded
            // BatteryPulse widget's frame is read.
            guard let inside, Rules.isRecordedWidget(inside) else {
                throw Refusal(description: "a widget host's tree is read only --inside a recorded widget frame")
            }
        } else if !own, text == nil, inside == nil {
            throw Refusal(description: "another app's tree is read only as --match <text> or --inside x y w h")
        }
        // Another app's labels and values are his: roles and frames only.
        let showsText = own || host
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
                let detail = showsText ? " \"\(AX.label(element))\" value \(AX.value(element))" : ""
                print("\(String(repeating: "  ", count: level))\(AX.role(element))\(detail) frame \(frame.map(describe) ?? "-")")
                printed += 1
            }
            for child in AX.children(element) { walk(child, level + 1) }
        }
        for root in roots.prefix(20) { walk(root, 0) }
        if printed == 0 { throw NotFound(description: "nothing matched") }
    }

    static func windows(_ options: Options) throws {
        // CGWindowList only: no AX into any process.
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
        let displays = Screen.displays()
        for window in all where filter.map({ $0.pid == window.pid }) ?? true {
            let owner = Processes.process(window.pid)
            var name = owner.bundle == Rules.batteryPulse ? " \"\(window.name)\"" : ""
            if Rules.isDockOverlay(window, displays: displays) { name = " (the Dock's full-display overlay: passed over)" }
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
            // The Dock's full-display overlay covers nothing (Rules.isDockOverlay).
            for window in all[..<index]
            where window.alpha > 0.01 && window.bounds.intersects(main.bounds) && window.pid != app.pid
                && !Rules.isDockOverlay(window, displays: displays)
            {
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

    static func thermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    static func thermal() {
        let hid = Screen.hidIdleSeconds().map { String(format: "%.1f", $0) } ?? "unknown"
        print("thermal=\(thermalState()) lowpower=\(ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 : 0) hid_idle_s=\(hid)")
    }

    /// The sampler's one line: HIDIdleTime, the lock and the lid, the screen saver's window,
    /// the thermal state and Low Power Mode, with no AX call.
    static func sample() {
        let hid = Screen.hidIdleSeconds().map { String(format: "%.1f", $0) } ?? "unknown"
        let list = Screen.windows()
        print(
            "hid_idle_s=\(hid) locked=\(Screen.isLocked(list) ? "yes" : "no") lid=\(Screen.isLidClosed() ? "closed" : "open") screensaver=\(Screen.screenSaverShows(list) ? "yes" : "no") thermal=\(thermalState()) lowpower=\(ProcessInfo.processInfo.isLowPowerModeEnabled ? 1 : 0)"
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
        // The fences and the script's lists live in the account's own home; a caller that moves the
        // home (CFFIXED_USER_HOME, which NSHomeDirectory and CFPreferences follow: the hot corners)
        // gets nothing.
        if ProcessInfo.processInfo.environment["CFFIXED_USER_HOME"] != nil {
            throw Refusal(description: "CFFIXED_USER_HOME is set: ui reads its fences only from the account's own home")
        }
        guard Account.home != nil else { throw Refusal(description: "the account's home folder can't be read") }
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
        case "close": try close(options)
        case "banner": try banner(options)
        case "quit": try quit(options)
        case "frame": try frame(options)
        case "hit": try hit(options)
        case "title": try title(options)
        case "pane-state": try paneState(options)
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
        "usage: ui click|move|drag|scroll|press|select-row|minimize|fullscreen|position|close|banner|quit|frame|title|pane-state|hit|tree|windows|idle|locked|thermal|sample|access|screen|guard ... (see ui.swift)"
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
