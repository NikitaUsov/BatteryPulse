// swift-tools-version: 6.4
import PackageDescription

// The language policy, in one place: every target, tests included, builds with these settings,
// and no target passes compiler flags of its own (the widget's one flag only shapes the
// extension; its entry point is a link flag of scripts/build-app.sh).
let strict: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
    .treatWarning("NoUseUnstructuredThrowingTask", as: .error),
    .treatWarning("ImplicitStrongCapture", as: .error),
    .treatWarning("ErrorInFutureSwiftVersion", as: .error),
]

let package = Package(
    name: "BatteryPulse",
    // Apple Silicon only: macOS 27 no longer runs on Intel Macs.
    platforms: [.macOS(.v27), .iOS(.v27)],
    products: [
        // Platform-independent models, parsing and metrics. Builds and tests on Linux.
        .library(name: "BatteryCore", targets: ["BatteryCore"]),
        // The battery and accessory reads: IOKit and the SMC on macOS, UIDevice on iOS, with their
        // loggers and signposts. The widget links it, BatteryCore and BatteryArt alone.
        .library(name: "BatterySource", targets: ["BatterySource"]),
        // OS integration on top of BatterySource: the observable monitors, iPhone and iPad reads,
        // and the CryptoKit code (device keys, update signatures).
        .library(name: "BatteryKit", targets: ["BatteryKit"]),
        // Command-line battery report (`swift run bpulse`). It reads this Mac's battery on macOS;
        // `--input` (a saved capture) and `--export` (a history folder) also run on Linux.
        .executable(name: "bpulse", targets: ["bpulse"]),
        // The menu-bar app (`swift run BatteryPulse`; `scripts/build-app.sh` packages it).
        .executable(name: "BatteryPulse", targets: ["BatteryPulseApp"]),
        // The widget extension; `scripts/build-app.sh` wraps it into the app as an .appex.
        .executable(name: "BatteryPulseWidget", targets: ["BatteryPulseWidget"]),
    ],
    targets: [
        // The parsers of untrusted input (captures, device property lists, the release JSON) live
        // here, so the compiler flags every unsafe construct. The one left is marked: C's
        // fixed-point formatting, which Darwin's Foundation declares unsafe (`BatteryReport`).
        .target(name: "BatteryCore", swiftSettings: strict + [.strictMemorySafety()]),
        // What the widget needs of the system and nothing more: no CryptoKit, no MobileDevice. Its
        // IOKit, SMC and notify(3) bindings mark each unsafe use `unsafe` with its reason.
        .target(name: "BatterySource", dependencies: ["BatteryCore"], swiftSettings: strict + [.strictMemorySafety()]),
        // Its MobileDevice and USB bindings mark each unsafe use `unsafe` with its reason, as
        // BatterySource's do.
        .target(
            name: "BatteryKit", dependencies: ["BatteryCore", "BatterySource"],
            swiftSettings: strict + [.strictMemorySafety()]),
        // The drawn battery of the menu bar icon, which the widget draws too: SwiftUI and Core Text
        // only, so it stays safe in an app extension. One painter keeps the two identical, on the
        // one geometry in BatteryCore. Neither a parser of untrusted input nor a system binding, it
        // builds without strict memory safety like the app, so its Core Text glyph calls, which
        // pass arrays as pointers, stay unmarked.
        .target(name: "BatteryArt", dependencies: ["BatteryCore"], swiftSettings: strict),
        // It reads capture files too. Its unsafe sites are marked: two Foundation calls that take
        // a pointer, and the macOS-only SMC listing's `String(format:)`.
        .executableTarget(
            name: "bpulse",
            dependencies: ["BatteryCore", "BatterySource", "BatteryKit"],
            swiftSettings: strict + [.strictMemorySafety()]
        ),
        // The app runs on the main actor unless its code says otherwise (`nonisolated`,
        // `@concurrent`). The other targets stay nonisolated, the widget too: WidgetKit calls its
        // timeline provider on threads of its own.
        .executableTarget(
            name: "BatteryPulseApp",
            dependencies: ["BatteryCore", "BatterySource", "BatteryKit", "BatteryArt"],
            swiftSettings: strict + [.defaultIsolation(MainActor.self)]
        ),
        .executableTarget(
            name: "BatteryPulseWidget",
            dependencies: ["BatteryCore", "BatterySource", "BatteryArt"],
            swiftSettings: strict + [
                // Allow only the APIs an app extension may use, as Xcode does for extension targets.
                .unsafeFlags(["-application-extension"], .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "BatteryCoreTests",
            dependencies: ["BatteryCore"],
            resources: [.copy("Fixtures")],
            swiftSettings: strict
        ),
        .testTarget(
            name: "BatterySourceTests", dependencies: ["BatterySource", "BatteryCore"], swiftSettings: strict),
        .testTarget(name: "BatteryKitTests", dependencies: ["BatteryKit", "BatterySource"], swiftSettings: strict),
        // The option parser; the output forms are covered by rendering the fixtures (`--input`).
        .testTarget(name: "bpulseTests", dependencies: ["bpulse", "BatteryCore"], swiftSettings: strict),
        // Renders the widget's sizes into PNGs for review (macOS only; CI uploads them).
        .testTarget(
            name: "BatteryPulseWidgetTests", dependencies: ["BatteryPulseWidget", "BatteryCore"], swiftSettings: strict),
    ]
)
