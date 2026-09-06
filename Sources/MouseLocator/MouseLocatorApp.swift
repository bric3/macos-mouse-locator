import AppKit
import SwiftUI

@main
struct MouseLocatorApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @AppStorage(LocatorDefaults.sonarEnabled) private var sonarEnabled = true
  @AppStorage(LocatorDefaults.tailEnabled) private var tailEnabled = true

  init() {
    LocatorDefaults.register()
  }

  var body: some Scene {
    MenuBarExtra("Mouse Locator", systemImage: "cursorarrow.rays") {
      Toggle("Mouse Tail", isOn: $tailEnabled)
      Toggle("Idle Sonar", isOn: $sonarEnabled)

      SettingsLink {
        Text("Settings…")
      }

      Divider()

      Button("Quit Mouse Locator") {
        NSApplication.shared.terminate(nil)
      }
    }

    Settings {
      SettingsView()
    }
  }
}
