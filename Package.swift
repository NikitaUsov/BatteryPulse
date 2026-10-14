// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BatteryPulse",
    // Apple Silicon only: macOS 27 no longer runs on Intel Macs.
    platforms: [.macOS("27.0"), .iOS("27.0")],
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
        .target(name: "BatteryCore"),
        .target(name: "BatteryKit", dependencies: ["BatteryCore"]),
        .executableTarget(name: "bpulse", dependencies: ["BatteryCore", "BatteryKit"]),
        .executableTarget(name: "BatteryPulseApp", dependencies: ["BatteryCore", "BatteryKit"]),
        .executableTarget(
            name: "BatteryPulseWidget",
            dependencies: ["BatteryCore", "BatteryKit"],
            swiftSettings: [.unsafeFlags(["-application-extension"], .when(platforms: [.macOS]))],
            linkerSettings: [
                // Start the way Xcode links app extensions. `@main` on the WidgetBundle keeps the
                // widgets in the binary; each is useless without the other.
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"], .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "BatteryCoreTests",
            dependencies: ["BatteryCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "BatteryKitTests", dependencies: ["BatteryKit"]),
    ]
)
