// swift-tools-version: 6.4
import PackageDescription

// The language policy, in one place: every target, tests included, builds with these settings,
// and no target passes compiler flags of its own (the widget's two flags only shape the extension).
let strict: [SwiftSetting] = [
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
        // Command-line battery report for macOS (`swift run bpulse`).
        .executable(name: "bpulse", targets: ["bpulse"]),
        // The menu-bar app (`swift run BatteryPulse`; `scripts/build-app.sh` packages it).
        .executable(name: "BatteryPulse", targets: ["BatteryPulseApp"]),
        // The widget extension; `scripts/build-app.sh` wraps it into the app as an .appex.
        .executable(name: "BatteryPulseWidget", targets: ["BatteryPulseWidget"]),
    ],
    targets: [
        .target(name: "BatteryCore", swiftSettings: strict),
        .target(name: "BatteryKit", dependencies: ["BatteryCore"], swiftSettings: strict),
        .executableTarget(name: "bpulse", dependencies: ["BatteryCore", "BatteryKit"], swiftSettings: strict),
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
