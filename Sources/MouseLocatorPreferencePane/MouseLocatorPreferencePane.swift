import AppKit
import PreferencePanes
import SwiftUI

@objc(MouseLocatorPreferencePane)
final class MouseLocatorPreferencePane: NSPreferencePane {
  override func loadMainView() -> NSView {
    let view = MainActor.assumeIsolated {
      let view = NSHostingView(
        rootView: SettingsView(settings: .shared)
          .frame(width: 660, height: 760)
          .scrollDisabled(true)
          .scrollIndicators(.hidden)
      )
      view.frame = NSRect(x: 0, y: 0, width: 660, height: 760)
      return view
    }
    mainView = view
    return view
  }
}
