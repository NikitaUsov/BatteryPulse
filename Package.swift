// swift-tools-version: 6.4
import PackageDescription

// The language policy, in one place: every target, tests included, builds with these settings,
// and no target passes compiler flags of its own (the widget's two flags only shape the extension).
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
        // OS integration: IOKit on macOS, UIDevice on iOS, plus the observable monitor.
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
        .target(name: "BatteryKit", dependencies: ["BatteryCore"], swiftSettings: strict),
        // It reads capture files too. Its unsafe sites are marked: two Foundation calls that take
        // a pointer, and the macOS-only SMC listing's `String(format:)`.
        .executableTarget(
            name: "bpulse",
            dependencies: ["BatteryCore", "BatteryKit"],
            swiftSettings: strict + [.strictMemorySafety()]
        ),
        .executableTarget(name: "BatteryPulseApp", dependencies: ["BatteryCore", "BatteryKit"], swiftSettings: strict),
        .executableTarget(
            name: "BatteryPulseWidget",
            dependencies: ["BatteryCore", "BatteryKit"],
            swiftSettings: strict + [
                // Allow only the APIs an app extension may use, as Xcode does for extension targets.
                .unsafeFlags(["-application-extension"], .when(platforms: [.macOS]))
            ],
            linkerSettings: [
                // Start the way Xcode links app extensions. `@main` on the WidgetBundle keeps the
                // widgets in the binary; each is useless without the other.
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"], .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "BatteryCoreTests",
            dependencies: ["BatteryCore"],
            resources: [.copy("Fixtures")],
            swiftSettings: strict
        ),
        .testTarget(name: "BatteryKitTests", dependencies: ["BatteryKit"], swiftSettings: strict),
    ]
)
