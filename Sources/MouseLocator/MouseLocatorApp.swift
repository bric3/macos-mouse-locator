import AppKit
import SwiftUI

@main
struct MouseLocatorApp: App {
  var body: some Scene {
    MenuBarExtra("Mouse Locator", systemImage: "cursorarrow.rays") {
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

private struct SettingsView: View {
  var body: some View {
    Text("Mouse Locator")
      .frame(width: 420, height: 180)
  }
}

