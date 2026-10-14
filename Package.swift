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
    ],
    targets: [
        .target(name: "BatteryCore"),
        .target(name: "BatteryKit", dependencies: ["BatteryCore"]),
        .executableTarget(name: "bpulse", dependencies: ["BatteryCore", "BatteryKit"]),
        .testTarget(
            name: "BatteryCoreTests",
            dependencies: ["BatteryCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "BatteryKitTests", dependencies: ["BatteryKit"]),
    ]
)
