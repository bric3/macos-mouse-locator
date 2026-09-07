import AppKit
import SwiftUI

@main
struct MouseLocatorApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var settings = LocatorSettings.shared

  var body: some Scene {
    MenuBarExtra(isInserted: $settings.menuBarIconEnabled) {
      Toggle("Mouse Tail", isOn: $settings.tailEnabled)
      Toggle("Idle Pulse", isOn: $settings.sonarEnabled)

      SettingsLink {
        Text("Settings…")
      }

      Divider()

      Button("Quit Mouse Locator") {
        NSApplication.shared.terminate(nil)
      }
    } label: {
      LocatorMenuBarIcon()
    }

    Settings {
      SettingsView(settings: settings)
        .frame(width: 460, height: 580)
    }
  }
}

private struct LocatorMenuBarIcon: View {
  var body: some View {
    ZStack {
      Circle()
        .stroke(lineWidth: 1.25)
        .frame(width: 16, height: 16)
        .opacity(0.55)
      Circle()
        .stroke(lineWidth: 1.25)
        .frame(width: 10, height: 10)
        .opacity(0.8)
      Image(systemName: "cursorarrow")
        .font(.system(size: 10, weight: .semibold))
        .offset(x: -1.5, y: 1.5)
    }
    .frame(width: 18, height: 18)
    .foregroundStyle(.primary)
    .accessibilityLabel("Mouse Locator")
  }
}
