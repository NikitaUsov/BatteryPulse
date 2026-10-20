#if os(macOS)
import AppKit
import BatteryCore
import SwiftUI

/// What the menu bar item shows and how its battery icon looks.
struct MenuBarSettings: View {
    @AppStorage(AppSettings.showInMenuBarKey) private var showInMenuBar = true
    private var choices = MenuBarChoices()

    private var content: MenuBarContent { choices.content }

    var body: some View {
        Section {
            // The last item that is on can't be turned off: the status item would be empty.
            Toggle("Battery icon", isOn: choices.$showsIcon)
                .disabled(content.isOnlyItem(.icon))
            Toggle("Percentage", isOn: choices.$showsCharge)
                .disabled(content.isOnlyItem(.charge))
            Toggle("Battery power", isOn: choices.$showsPower)
                .disabled(content.isOnlyItem(.power))
            Toggle("Temperature", isOn: choices.$showsTemperature)
                .disabled(content.isOnlyItem(.temperature))
        } header: {
            Text("Show")
        } footer: {
            if showInMenuBar {
                Text("The menu bar always shows at least one item.")
            } else {
                Text("BatteryPulse isn't in the menu bar. Turn it on in General.")
            }
        }
        .disabled(!showInMenuBar)

        Section {
            PreviewTilePicker(
                selection: choices.$iconStyle, values: MenuBarIconStyle.allCases, title: \.title
            ) { style in
                MenuBarIconPreview(style: style, magnification: PreviewTile.iconMagnification)
            }
        } header: {
            Text("Icon Style")
        }
        .disabled(!showInMenuBar || !content.items.contains(.icon))

        Section {
            LabeledContent("macOS battery item") {
                Button("Open Menu Bar Settings…") {
                    NSWorkspace.shared.open(AppLinks.menuBarSettings)
                }
            }
        } footer: {
            Text(
                "BatteryPulse can't hide the battery item macOS shows. To use BatteryPulse in its place, turn off Battery in System Settings → Menu Bar."
            )
        }
    }
}
#endif
