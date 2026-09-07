// Copyright 2026 Brice Dutheil
// SPDX-License-Identifier: MPL-2.0

import AppKit
import PreferencePanes
import SwiftUI

@objc(MouseLocatorPreferencePane)
final class MouseLocatorPreferencePane: NSPreferencePane {
  override func didSelect() {
    super.didSelect()
    MainActor.assumeIsolated {
      LocatorSettings.shared.requestAccessibilityStatus()
    }
  }

  override func willUnselect() {
    MainActor.assumeIsolated {
      LocatorSettings.shared.flush()
    }
    super.willUnselect()
  }

  override func loadMainView() -> NSView {
    let view = MainActor.assumeIsolated {
      let view = NSHostingView(
        rootView: SettingsView(settings: .shared)
          .frame(width: 660, height: 1_020)
          .scrollDisabled(true)
          .scrollIndicators(.hidden)
      )
      view.frame = NSRect(x: 0, y: 0, width: 660, height: 1_020)
      return view
    }
    mainView = view
    return view
  }
}
