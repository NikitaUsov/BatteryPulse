import Foundation

/// A page of the main window, as `@SceneStorage("mainSelection")` keeps it: a name, or `device:`
/// and the device's key. The strings are frozen: a window restores its page from them, and a
/// widget's click names its page with them.
public enum PageID: Hashable, Sendable, RawRepresentable {
    case overview, power, health, history, developer, demo
    /// The Devices section's introduction.
    case devices
    case accessories
    /// A remembered iPhone or iPad.
    case device(DeviceKey)

    /// Every page with a name of its own, in the sidebar's order.
    public static let named: [PageID] = [
        .overview, .power, .health, .history, .developer, .demo, .devices, .accessories,
    ]

    public static let devicePrefix = "device:"

    public init?(rawValue: String) {
        if rawValue.hasPrefix(Self.devicePrefix) {
            guard let key = DeviceKey(rawValue: String(rawValue.dropFirst(Self.devicePrefix.count))) else {
                return nil
            }
            self = .device(key)
            return
        }
        guard let page = Self.named.first(where: { $0.rawValue == rawValue }) else { return nil }
        self = page
    }

    public var rawValue: String {
        switch self {
        case .overview: "overview"
        case .power: "power"
        case .health: "health"
        case .history: "history"
        case .developer: "developer"
        case .demo: "demo"
        case .devices: "devices"
        case .accessories: "accessories"
        case .device(let key): Self.devicePrefix + key.rawValue
        }
    }
}

/// The page a widget's click opens, and the URL that carries it:
/// `io.github.nikitausov.batterypulse://page/<page>`, or `…://page/device/<key>` for an iPhone or
/// iPad. Navigation only: a link never acts, and any app or web page that opens one can do no more
/// than show a page. A widget never opens Raw Data, Demo Mode or Demo Mode's iPhone, so those
/// pages have no route.
public struct WidgetRoute: Hashable, Sendable {
    /// Derived from the bundle identifier, so no other app's links collide with it.
    public static let scheme = "io.github.nikitausov.batterypulse"
    public static let host = "page"

    public let page: PageID

    public init?(page: PageID) {
        switch page {
        case .overview, .power, .health, .history, .devices, .accessories: break
        case .developer, .demo: return nil
        case .device(let key): guard key != .demo else { return nil }
        }
        self.page = page
    }

    /// A page ``init(page:)`` accepts.
    init(widgetPage page: PageID) {
        self.page = page
    }

    /// The route a widget's URL names; `nil` for any other URL, so the app ignores it.
    public init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == Self.scheme, components.host?.lowercased() == Self.host,
            components.user == nil, components.password == nil, components.port == nil,
            components.query == nil, components.fragment == nil
        else { return nil }
        let path = components.path.split(separator: "/", omittingEmptySubsequences: false)
        guard path.first == "" else { return nil }
        let page: PageID?
        switch path.count {
        case 2 where path[1] != "device":
            page = PageID(rawValue: String(path[1])).flatMap { if case .device = $0 { nil } else { $0 } }
        case 3 where path[1] == "device":
            page = DeviceKey(rawValue: String(path[2])).map(PageID.device)
        default:
            page = nil
        }
        guard let page else { return nil }
        self.init(page: page)
    }

    public var url: URL {
        switch page {
        case .device(let key): Self.url("\(Self.scheme)://\(Self.host)/device/\(key.rawValue)")
        default: Self.url("\(Self.scheme)://\(Self.host)/\(page.rawValue)")
        }
    }

    /// The pages' names and device keys are lowercase letters, digits and hyphens.
    // swift-format-ignore: NeverForceUnwrap
    private static func url(_ string: String) -> URL {
        URL(string: string)!
    }
}
