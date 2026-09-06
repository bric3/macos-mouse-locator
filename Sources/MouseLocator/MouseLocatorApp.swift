import AppKit
import SwiftUI

@main
struct MouseLocatorApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var settings = LocatorSettings.shared

  var body: some Scene {
    MenuBarExtra("Mouse Locator", systemImage: "cursorarrow.rays") {
      Toggle("Mouse Tail", isOn: $settings.tailEnabled)
      Toggle("Idle Sonar", isOn: $settings.sonarEnabled)

      SettingsLink {
        Text("Settings…")
      }

      Divider()

      Button("Quit Mouse Locator") {
        NSApplication.shared.terminate(nil)
      }
    }

    Settings {
      SettingsView(settings: settings)
        .frame(width: 460, height: 580)
    }
  }
}
