import Foundation

/// A page of the main window, as `@SceneStorage("mainSelection")` keeps it: a name, or `device:`
/// and the device's key. The strings are frozen: a window restores its page from them, and a
/// widget's click names its page with them.
enum PageID: Hashable, Sendable, RawRepresentable {
    case overview, power, health, history, developer, demo
    /// The Devices section's introduction.
    case devices
    case accessories
    /// A remembered iPhone or iPad.
    case device(DeviceKey)

    /// Every page with a name of its own, in the sidebar's order.
    static let named: [PageID] = [
        .overview, .power, .health, .history, .developer, .demo, .devices, .accessories,
    ]

    static let devicePrefix = "device:"

    init?(rawValue: String) {
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

    var rawValue: String {
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

/// The page a widget's click opens, and the URL that carries it: `batterypulse://page/<page>`, or
/// `batterypulse://page/device/<key>` for an iPhone or iPad. Navigation only: a link never acts,
/// it only shows a page. A widget never opens Raw Data, Demo Mode or Demo Mode's iPhone, so those
/// pages have no route.
public struct WidgetRoute: Hashable, Sendable {
    /// Not registered with Launch Services: WidgetKit hands a widget's URL to the widget's own app
    /// without it, as a click on the M5 showed (`batterypulse://page/overview` reached the app
    /// delegate with no scheme registered), so no other app or web page opens a page with it.
    static let scheme = "batterypulse"
    static let host = "page"

    let page: PageID

    init?(page: PageID) {
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
    init?(url: URL) {
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

    /// The route of a click that carries no URL: macOS hands the app an `NSUserActivity` whose
    /// type is the clicked widget's configuration intent type name, with no configuration the app
    /// reads. An intent of `manifest` opens its kind's page (``WidgetKindID/page``); any other
    /// activity type is `nil`, so the app ignores it. The activity's user info isn't read.
    init?(activityType: String, manifest: WidgetIntentManifest = .shipping) {
        guard let declared = manifest.kinds.first(where: { $0.intent?.type == activityType }),
            let kind = WidgetKindID(rawValue: declared.kind)
        else { return nil }
        self.init(page: kind.page)
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

extension WidgetKindID {
    /// The page a click on the kind's widget opens when it names none: the kind's own subject.
    var page: PageID {
        switch self {
        case .battery: .overview
        case .accessories: .accessories
        }
    }
}
