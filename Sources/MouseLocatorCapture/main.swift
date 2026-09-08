// Copyright 2026 Brice Dutheil
// SPDX-License-Identifier: MPL-2.0

import AppKit
import CoreGraphics
import Darwin
import ImageIO
import MouseLocatorCore
@preconcurrency import ScreenCaptureKit

private let width = 900
private let height = 520
private let trailWaypoints = [
  CGPoint(x: 0.07, y: 0.20),
  CGPoint(x: 0.26, y: 0.58),
  CGPoint(x: 0.28, y: 0.22),
  CGPoint(x: 0.56, y: 0.67),
  CGPoint(x: 0.51, y: 0.14),
  CGPoint(x: 0.76, y: 0.61),
]
private let scenarios = [
  Scenario(name: "trail", tail: true, pulse: false, rainbow: false),
  Scenario(name: "idle-pulse", tail: false, pulse: true, rainbow: false),
  Scenario(name: "both", tail: true, pulse: true, rainbow: false),
  Scenario(name: "rainbow-trail", tail: true, pulse: false, rainbow: true),
]

@MainActor
private func run() async -> Int32 {
  guard CGPreflightScreenCaptureAccess() else {
    fputs(
      "Screen Recording permission is required. Enable it for the terminal running make in "
        + "System Settings > Privacy & Security > Screen & System Audio Recording, then rerun "
        + "make screenshots.\n",
      stderr
    )
    return 2
  }
  if CommandLine.arguments.contains("--check-permissions") {
    print("Screen Recording permission is granted.")
    return 0
  }

  do {
    try await captureShowcases()
    return 0
  } catch {
    fputs("Screenshot capture failed: \(error.localizedDescription)\n", stderr)
    return 1
  }
}

@MainActor
private func captureShowcases() async throws {
  let fileManager = FileManager.default
  let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
  let app = root.appendingPathComponent(".build/MouseLocator.app/Contents/MacOS/MouseLocator")
  guard fileManager.isExecutableFile(atPath: app.path) else {
    throw CaptureError("Run `make app` before capturing screenshots")
  }

  guard
    let screen = NSScreen.main,
    let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
      as? NSNumber
  else {
    throw CaptureError("No display is available")
  }

  let displayID = CGDirectDisplayID(screenNumber.uint32Value)
  let content = try await SCShareableContent.excludingDesktopWindows(
    false,
    onScreenWindowsOnly: true
  )
  guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
    throw CaptureError("The main display is not available to ScreenCaptureKit")
  }

  let output = root.appendingPathComponent(".github/docs/images", isDirectory: true)
  try fileManager.createDirectory(at: output, withIntermediateDirectories: true)
  let configHome = fileManager.temporaryDirectory.appendingPathComponent(
    "mouse-locator-showcase-\(UUID().uuidString)",
    isDirectory: true
  )
  try fileManager.createDirectory(at: configHome, withIntermediateDirectories: true)

  let installedApp = fileManager.homeDirectoryForCurrentUser
    .appendingPathComponent("Applications/MouseLocator.app", isDirectory: true)
  let installedWasRunning = NSRunningApplication.runningApplications(
    withBundleIdentifier: "dev.brice.MouseLocator"
  ).contains { $0.bundleURL?.standardizedFileURL == installedApp.standardizedFileURL }
  await stopRunningLocators()

  NSApplication.shared.setActivationPolicy(.accessory)
  let panelSize = NSSize(width: CGFloat(width), height: CGFloat(height))
  let panelOrigin = NSPoint(
    x: screen.visibleFrame.midX - panelSize.width / 2,
    y: screen.visibleFrame.midY - panelSize.height / 2
  )
  let panelFrame = NSRect(origin: panelOrigin, size: panelSize)
  let panel: NSWindow = NSWindow(
    contentRect: panelFrame,
    styleMask: .borderless,
    backing: .buffered,
    defer: false
  )
  panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1)
  panel.isOpaque = true
  panel.hasShadow = false
  panel.sharingType = NSWindow.SharingType.readOnly
  panel.orderFrontRegardless()

  let sourceRect = CGRect(
    x: panelFrame.minX - screen.frame.minX,
    y: screen.frame.maxY - panelFrame.maxY,
    width: CGFloat(width),
    height: CGFloat(height)
  )
  let displayBounds = CGDisplayBounds(displayID)
  let captureOrigin = CGPoint(
    x: displayBounds.minX + sourceRect.minX,
    y: displayBounds.minY + sourceRect.minY
  )
  let originalCursor = CGEvent(source: nil)?.location

  defer {
    panel.close()
    if let originalCursor { CGWarpMouseCursorPosition(originalCursor) }
    try? fileManager.removeItem(at: configHome)
    if installedWasRunning { NSWorkspace.shared.open(installedApp) }
  }

  let filter = SCContentFilter(display: display, excludingWindows: [])
  for dark in [false, true] {
    panel.backgroundColor =
      dark
      ? NSColor(srgbRed: 24.0 / 255, green: 24.0 / 255, blue: 24.0 / 255, alpha: 1)
      : NSColor(srgbRed: 250.0 / 255, green: 250.0 / 255, blue: 250.0 / 255, alpha: 1)
    panel.displayIfNeeded()
    try await pause(milliseconds: 150)

    for scenario in scenarios {
      try await capture(
        app: app,
        configHome: configHome,
        output: output,
        captureOrigin: captureOrigin,
        sourceRect: sourceRect,
        filter: filter,
        scenario: scenario,
        dark: dark
      )
    }
  }

  try verifyScreenshots(in: output)
  print("Wrote light and dark showcase screenshots to \(output.path)")
}

@MainActor
private func capture(
  app: URL,
  configHome: URL,
  output: URL,
  captureOrigin: CGPoint,
  sourceRect: CGRect,
  filter: SCContentFilter,
  scenario: Scenario,
  dark: Bool
) async throws {
  let start =
    scenario.tail
    ? trailPosition(progress: 0, captureOrigin: captureOrigin)
    : CGPoint(x: captureOrigin.x + CGFloat(width) / 2 - 2, y: captureOrigin.y + CGFloat(height) / 2)
  try warpCursor(to: start)

  let settingsURL = configHome.appendingPathComponent("mouse-locator/settings.toml")
  try FileManager.default.createDirectory(
    at: settingsURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try Settings(scenario: scenario, dark: dark).toml.write(
    to: settingsURL, atomically: true, encoding: .utf8)

  let overlay = Process()
  overlay.executableURL = app
  overlay.arguments = [
    "--config-home=\(configHome.path)",
    dark ? "--dark-appearance" : "--light-appearance",
  ]
  try overlay.run()
  defer {
    overlay.terminate()
    overlay.waitUntilExit()
  }

  let configuration = SCStreamConfiguration()
  configuration.sourceRect = sourceRect
  configuration.width = width
  configuration.height = height
  configuration.showsCursor = true

  try await pause(milliseconds: scenario.pulse ? 1_800 : 500)
  var frames: [CGImage] = []
  if scenario.tail {
    let movementFrames = 8
    let movementsPerFrame = 9
    for frame in 1...movementFrames {
      for movement in 1...movementsPerFrame {
        let progress =
          CGFloat((frame - 1) * movementsPerFrame + movement)
          / CGFloat(movementFrames * movementsPerFrame)
        try warpCursor(to: trailPosition(progress: progress, captureOrigin: captureOrigin))
        try await pause(milliseconds: 3)
      }
      try await pause(milliseconds: 6)
      frames.append(try await captureFrame(filter: filter, configuration: configuration))
    }
    for _ in 0..<(scenario.pulse ? 16 : 8) {
      try await pause(milliseconds: 70)
      frames.append(try await captureFrame(filter: filter, configuration: configuration))
    }
  } else {
    try warpCursor(to: CGPoint(x: start.x + 4, y: start.y))
    for _ in 0..<36 {
      try await pause(milliseconds: 55)
      frames.append(try await captureFrame(filter: filter, configuration: configuration))
    }
  }

  let appearance = dark ? "dark" : "light"
  try writeAnimatedPNG(
    frames,
    to: output.appendingPathComponent("\(scenario.name)-\(appearance).png")
  )
}

private func trailPosition(progress: CGFloat, captureOrigin: CGPoint) -> CGPoint {
  let scaled = min(max(progress, 0), 1) * CGFloat(trailWaypoints.count - 1)
  let index = min(Int(scaled), trailWaypoints.count - 2)
  let amount = scaled - CGFloat(index)
  let start = trailWaypoints[index]
  let end = trailWaypoints[index + 1]
  return CGPoint(
    x: captureOrigin.x + CGFloat(width) * (start.x + (end.x - start.x) * amount),
    y: captureOrigin.y + CGFloat(height) * (start.y + (end.y - start.y) * amount)
  )
}

@MainActor
private func captureFrame(
  filter: SCContentFilter,
  configuration: SCStreamConfiguration
) async throws -> CGImage {
  try await SCScreenshotManager.captureImage(
    contentFilter: filter,
    configuration: configuration
  )
}

private func writeAnimatedPNG(_ frames: [CGImage], to url: URL) throws {
  let temporaryURL = url.deletingLastPathComponent()
    .appendingPathComponent(".\(url.lastPathComponent).tmp")
  defer { try? FileManager.default.removeItem(at: temporaryURL) }

  guard
    let destination = CGImageDestinationCreateWithURL(
      temporaryURL as CFURL,
      "public.png" as CFString,
      frames.count,
      nil
    )
  else {
    throw CaptureError("Could not create \(url.lastPathComponent)")
  }

  CGImageDestinationSetProperties(
    destination,
    [
      kCGImagePropertyPNGDictionary as String: [
        kCGImagePropertyAPNGLoopCount as String: 0
      ]
    ] as CFDictionary
  )
  let frameProperties =
    [
      kCGImagePropertyPNGDictionary as String: [
        kCGImagePropertyAPNGDelayTime as String: 1.0 / 12
      ]
    ] as CFDictionary
  for frame in frames {
    CGImageDestinationAddImage(destination, frame, frameProperties)
  }
  guard CGImageDestinationFinalize(destination) else {
    throw CaptureError("Could not finish \(url.lastPathComponent)")
  }
  try Data(contentsOf: temporaryURL).write(to: url, options: .atomic)
}

@MainActor
private func stopRunningLocators() async {
  let applications = NSRunningApplication.runningApplications(
    withBundleIdentifier: "dev.brice.MouseLocator"
  )
  for application in applications { application.terminate() }
  try? await pause(milliseconds: 300)
  for application in applications where !application.isTerminated { application.forceTerminate() }
  try? await pause(milliseconds: 300)
}

private func warpCursor(to point: CGPoint) throws {
  let result = CGWarpMouseCursorPosition(point)
  guard result == .success else {
    throw CaptureError("Could not move the pointer (CoreGraphics error \(result.rawValue))")
  }
  CGEvent(
    mouseEventSource: nil,
    mouseType: .mouseMoved,
    mouseCursorPosition: point,
    mouseButton: .left
  )?.post(tap: .cghidEventTap)
}

private func pause(milliseconds: UInt64) async throws {
  try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
}

private func verifyScreenshots(in output: URL) throws {
  for scenario in scenarios {
    for appearance in ["light", "dark"] {
      let url = output.appendingPathComponent("\(scenario.name)-\(appearance).png")
      guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        CGImageSourceGetCount(source) > 1,
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
        image.width == width,
        image.height == height
      else {
        throw CaptureError("Invalid animated screenshot: \(url.path)")
      }
    }
  }
}

private struct Scenario {
  let name: String
  let tail: Bool
  let pulse: Bool
  let rainbow: Bool
}

private struct Settings {
  let menuBarIconEnabled = false
  let modifierPulseEnabled = false
  let modifierPulseKey = "control"
  let modifierTapDuration = 0.35
  let sonarColor: String
  let sonarDelay = 1.0
  let sonarEnabled: Bool
  let sonarExpansionSpeed = 1.0
  let sonarRainbow = false
  let sonarSize = 240.0
  let sonarThickness = 6.0
  let tailColor: String
  let tailActivationMode = "always"
  let tailDotsEnabled = false
  let tailEnabled: Bool
  let tailGap = 16.0
  let tailInactivityDelay = 3.0
  let tailRainbow: Bool
  let tailSpeedShadingEnabled = true
  let tailSmoothing = "bezier"
  let tailThickness = 8.0

  init(scenario: Scenario, dark: Bool) {
    sonarColor = dark ? "#69AFFF" : "#006BD6"
    sonarEnabled = scenario.pulse
    tailColor = sonarColor
    tailEnabled = scenario.tail
    tailRainbow = scenario.rainbow
  }

  var toml: String {
    get throws {
      try FlatTOML.document(
        header: [
          "Mouse Locator settings",
          "Key names are not stable yet and may change before the first stable release.",
          "modifierTapDuration is the maximum modifier-only tap length in seconds.",
        ],
        fields: [
          ("menuBarIconEnabled", String(menuBarIconEnabled)),
          ("modifierPulseEnabled", String(modifierPulseEnabled)),
          ("modifierPulseKey", FlatTOML.quoted(modifierPulseKey)),
          ("modifierTapDuration", String(modifierTapDuration)),
          ("tailEnabled", String(tailEnabled)),
          ("tailActivationMode", FlatTOML.quoted(tailActivationMode)),
          ("tailInactivityDelay", String(tailInactivityDelay)),
          ("tailColor", FlatTOML.quoted(tailColor)),
          ("tailRainbow", String(tailRainbow)),
          ("tailSpeedShadingEnabled", String(tailSpeedShadingEnabled)),
          ("tailThickness", String(tailThickness)),
          ("tailGap", String(tailGap)),
          ("tailDotsEnabled", String(tailDotsEnabled)),
          ("tailSmoothing", FlatTOML.quoted(tailSmoothing)),
          ("sonarEnabled", String(sonarEnabled)),
          ("sonarDelay", String(sonarDelay)),
          ("sonarColor", FlatTOML.quoted(sonarColor)),
          ("sonarRainbow", String(sonarRainbow)),
          ("sonarExpansionSpeed", String(sonarExpansionSpeed)),
          ("sonarThickness", String(sonarThickness)),
          ("sonarSize", String(sonarSize)),
        ]
      )
    }
  }
}

private struct CaptureError: LocalizedError {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var errorDescription: String? { message }
}

exit(await run())
