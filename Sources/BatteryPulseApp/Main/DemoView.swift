#if os(macOS)
import BatteryCore
import SwiftUI

/// The Demo Mode page: start the tour or pick a scene or animation by hand.
struct DemoView: View {
    @Environment(DemoController.self) private var demo

    var body: some View {
        @Bindable var demo = demo
        Form {
            Section {
                Text(
                    "Demo Mode fills BatteryPulse with simulated data, so you can see every state — charging, low battery, a worn battery and more — without touching the charger. The menu bar shows it too. Nothing on your Mac changes, and real readings come back when you stop."
                )
                .foregroundStyle(.secondary)
                HStack {
                    if demo.isPlaying {
                        Button("Pause Tour", systemImage: "pause.fill") { demo.togglePlayback() }
                    } else if demo.isActive {
                        Button("Resume Tour", systemImage: "play.fill") { demo.togglePlayback() }
                    } else {
                        Button("Start Tour", systemImage: "play.fill") { demo.startTour() }
                            .buttonStyle(.borderedProminent)
                    }
                    if demo.isActive {
                        Button("Stop Demo", systemImage: "stop.fill") { demo.stop() }
                    }
                }
            }

            Section {
                Picker("Scene length", selection: $demo.sceneLength) {
                    ForEach(DemoController.sceneLengths, id: \.self) { length in
                        Text(length.formatted(.units(allowed: [.seconds], width: .wide)))
                            .tag(length)
                    }
                }
            } header: {
                Text("Tour")
            } footer: {
                Text("The tour switches pages by itself and starts over after the last scene.")
            }

            Section("Scenes") {
                ForEach(DemoScenario.allCases) { scenario in
                    DemoStepRow(step: .scene(scenario))
                }
            }

            Section("Animations") {
                ForEach(DemoAnimation.allCases) { animation in
                    DemoStepRow(step: .animation(animation))
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// A scene or animation; clicking it shows it on the page that suits it best.
private struct DemoStepRow: View {
    let step: DemoController.Step
    @Environment(DemoController.self) private var demo

    var body: some View {
        Button {
            demo.show(step)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: step.symbol)
                    .font(.title3)
                    .foregroundStyle(step.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                    Text(step.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if demo.step == step {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Showing")
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Floating controls at the bottom of the main window while Demo Mode is on, so it's always
/// clear the numbers are simulated and the demo can be stepped through or stopped from any page.
struct DemoControlBar: View {
    @Environment(DemoController.self) private var demo

    var body: some View {
        if let step = demo.step {
            HStack(spacing: 12) {
                Label("Demo", systemImage: "play.rectangle.on.rectangle")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(step.title)
                    .font(.callout)
                    .lineLimit(1)
                Divider()
                    .frame(height: 16)
                Group {
                    Button("Previous Scene", systemImage: "backward.fill") { demo.previous() }
                        .help("Previous Scene")
                    if demo.isPlaying {
                        Button("Pause", systemImage: "pause.fill") { demo.togglePlayback() }
                            .help("Pause")
                    } else {
                        Button("Play", systemImage: "play.fill") { demo.togglePlayback() }
                            .help("Play")
                    }
                    Button("Next Scene", systemImage: "forward.fill") { demo.next() }
                        .help("Next Scene")
                    Button("Stop Demo", systemImage: "xmark") { demo.stop() }
                        .help("Stop Demo")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            // A floating control, so it belongs to the Liquid Glass layer.
            .glassEffect(in: .capsule)
            .padding(.bottom, 14)
        }
    }
}
#endif
