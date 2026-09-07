// Copyright 2026 Brice Dutheil
// SPDX-License-Identifier: MPL-2.0

import AppKit
import SwiftUI

@main
struct MouseLocatorApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var settings = LocatorSettings.shared

  var body: some Scene {
    Settings {
      SettingsView(settings: settings)
        .frame(width: 460, height: 580)
    }
  }
}

@MainActor
let locatorMenuBarImage: NSImage = {
  let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
    NSColor.black.setStroke()
    for circle in [
      NSRect(x: 1, y: 1, width: 16, height: 16),
      NSRect(x: 4, y: 4, width: 10, height: 10),
    ] {
      let path = NSBezierPath(ovalIn: circle)
      path.lineWidth = 1.25
      path.stroke()
    }

    let cursor = NSBezierPath()
    cursor.move(to: NSPoint(x: 4, y: 16))
    cursor.line(to: NSPoint(x: 14, y: 6))
    cursor.line(to: NSPoint(x: 10, y: 6))
    cursor.line(to: NSPoint(x: 7.5, y: 2))
    cursor.close()
    NSGraphicsContext.current?.compositingOperation = .clear
    cursor.lineWidth = 2.5
    cursor.stroke()
    cursor.fill()
    NSGraphicsContext.current?.compositingOperation = .sourceOver
    NSColor.black.setFill()
    cursor.fill()
    return true
  }
  image.isTemplate = true
  return image
}()
