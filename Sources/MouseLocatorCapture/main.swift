import AppKit
import CoreGraphics
import Darwin
import ScreenCaptureKit

private let width = 900
private let height = 520
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
  panel.level = NSWindow.Level.floating
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
    ? CGPoint(x: captureOrigin.x + 120, y: captureOrigin.y + CGFloat(height) * 0.75)
    : CGPoint(x: captureOrigin.x + CGFloat(width) / 2 - 2, y: captureOrigin.y + CGFloat(height) / 2)
  try warpCursor(to: start)

  let settingsURL = configHome.appendingPathComponent("mouse-locator/settings.json")
  try FileManager.default.createDirectory(
    at: settingsURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  try encoder.encode(Settings(scenario: scenario, dark: dark)).write(
    to: settingsURL, options: .atomic)

  let overlay = Process()
  overlay.executableURL = app
  overlay.arguments = ["--config-home=\(configHome.path)"]
  try overlay.run()
  defer {
    overlay.terminate()
    overlay.waitUntilExit()
  }

  try await pause(milliseconds: scenario.pulse ? 1_800 : 500)
  if scenario.tail {
    for step in 0...70 {
      let progress = CGFloat(step) / 70
      try warpCursor(
        to: CGPoint(
          x: captureOrigin.x + 120 + CGFloat(width - 240) * progress,
          y: captureOrigin.y + CGFloat(height) * 0.75
            - CGFloat(height) * 0.42 * sin(.pi * progress)
            + 35 * sin(2 * .pi * progress)
        )
      )
      try await pause(milliseconds: 5)
    }
  } else {
    try warpCursor(to: CGPoint(x: start.x + 4, y: start.y))
    try await pause(milliseconds: 1_000)
  }
  try await pause(milliseconds: 40)

  let configuration = SCStreamConfiguration()
  configuration.sourceRect = sourceRect
  configuration.width = width
  configuration.height = height
  configuration.showsCursor = true
  let image = try await SCScreenshotManager.captureImage(
    contentFilter: filter,
    configuration: configuration
  )
  guard
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
  else {
    throw CaptureError("Could not encode \(scenario.name) as PNG")
  }
  let appearance = dark ? "dark" : "light"
  try png.write(
    to: output.appendingPathComponent("\(scenario.name)-\(appearance).png"),
    options: .atomic
  )
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
}

private func pause(milliseconds: UInt64) async throws {
  try await Task.sleep(nanoseconds: milliseconds * 1_000_000)
}

private func verifyScreenshots(in output: URL) throws {
  for scenario in scenarios {
    for appearance in ["light", "dark"] {
      let url = output.appendingPathComponent("\(scenario.name)-\(appearance).png")
      guard
        let data = try? Data(contentsOf: url),
        let image = NSBitmapImageRep(data: data),
        image.pixelsWide == width,
        image.pixelsHigh == height
      else {
        throw CaptureError("Invalid screenshot: \(url.path)")
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

private struct Settings: Encodable {
  let sonarColor: String
  let sonarDelay = 1.0
  let sonarEnabled: Bool
  let sonarRainbow = false
  let sonarSize = 240.0
  let sonarThickness = 3.0
  let tailColor: String
  let tailDotsEnabled = false
  let tailEnabled: Bool
  let tailGap = 16.0
  let tailRainbow: Bool
  let tailSmoothing = "bezier"
  let tailThickness = 3.0

  init(scenario: Scenario, dark: Bool) {
    sonarColor = dark ? "#69AFFF" : "#006BD6"
    sonarEnabled = scenario.pulse
    tailColor = sonarColor
    tailEnabled = scenario.tail
    tailRainbow = scenario.rainbow
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
