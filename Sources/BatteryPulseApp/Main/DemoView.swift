#if os(macOS)
import BatteryCore
import SwiftUI

/// The Demo Mode page: start the tour or pick a scene or animation by hand.
struct DemoView: View {
    @Environment(DemoController.self) private var demo
    @Environment(\.motion) private var motion

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
                // The buttons swap when the demo starts, pauses, resumes or stops.
                .animation(motion.change, value: demo.isActive)
                .animation(motion.change, value: demo.isPlaying)
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
                        .transition(.opacity)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Floating controls at the bottom of the main window while Demo Mode is on, so it's always
/// clear the numbers are simulated and the demo can be stepped through or stopped from any page.
///
/// The only custom Liquid Glass in the app: a control that floats over content. It materializes
/// when the demo starts and dissolves when it stops (DemoController changes the step inside an
/// animation), and the capsule follows the width of each scene's title.
struct DemoControlBar: View {
    @Environment(DemoController.self) private var demo
    @Environment(\.motion) private var motion
    @Namespace private var glass

    var body: some View {
        GlassEffectContainer {
            ZStack {
                if let step = demo.step {
                    bar(step)
                        // A floating control, so it belongs to the Liquid Glass layer. Interactive:
                        // the capsule responds to clicks on its buttons (macOS 27).
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .glassEffectID("demoBar", in: glass)
                        // Under Reduce Motion the bar only fades: no materializing into or out of
                        // a blur.
                        .glassEffectTransition(motion.level == .full ? .materialize : .identity)
                        .padding(.bottom, 14)
                        .transition(.opacity)
                }
            }
        }
    }

    private func bar(_ step: DemoController.Step) -> some View {
        HStack(spacing: 12) {
            Label("Demo", systemImage: "play.rectangle.on.rectangle")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.orange)
            // Crossfades in place to the next scene's title; an `.id` with a transition would put
            // both titles side by side in the HStack while they fade.
            Text(step.title)
                .font(.callout)
                .lineLimit(1)
                .contentTransition(.opacity)
            Divider()
                .frame(height: 16)
            Group {
                Button("Previous Scene", systemImage: "backward.fill") { demo.previous() }
                    .help("Previous Scene")
                playPauseButton
                Button("Next Scene", systemImage: "forward.fill") { demo.next() }
                    .help("Next Scene")
                Button("Stop Demo", systemImage: "xmark") { demo.stop() }
                    .help("Stop Demo")
            }
            .labelStyle(.iconOnly)
            // Controls on glass stay borderless: no glass on glass.
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// One button whose symbol swaps between Play and Pause (DemoController changes it inside an
    /// animation).
    private var playPauseButton: some View {
        Button {
            demo.togglePlayback()
        } label: {
            Label {
                if demo.isPlaying { Text("Pause") } else { Text("Play") }
            } icon: {
                Image(systemName: demo.isPlaying ? "pause.fill" : "play.fill")
                    .contentTransition(motion.symbolSwap)
            }
        }
        .help(demo.isPlaying ? Text("Pause") : Text("Play"))
    }
}
#endif
