import AppKit
import PreferencePanes
import SwiftUI

@objc(MouseLocatorPreferencePane)
final class MouseLocatorPreferencePane: NSPreferencePane {
  override func loadMainView() -> NSView {
    let view = MainActor.assumeIsolated {
      let view = NSHostingView(rootView: SettingsView(settings: .shared))
      view.frame = NSRect(x: 0, y: 0, width: 460, height: 530)
      return view
    }
    mainView = view
    return view
  }
}
