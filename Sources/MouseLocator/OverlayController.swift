import AppKit
import Combine
import MouseLocatorCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var overlayController: OverlayController?
  private var statusItem: NSStatusItem?
  private var visibilityObserver: AnyCancellable?

  func applicationDidFinishLaunching(_ notification: Notification) {
    if CommandLine.arguments.contains("--unregister-login") {
      setLaunchAtLogin(false)
      NSApplication.shared.terminate(nil)
      return
    }
    if CommandLine.arguments.contains("--register-login") {
      setLaunchAtLogin(true)
    }

    overlayController = OverlayController()
    overlayController?.start()
    visibilityObserver = LocatorSettings.shared.$menuBarIconEnabled
      .removeDuplicates()
      .sink { [weak self] enabled in
        Task { @MainActor in
          self?.setStatusItemVisible(enabled)
        }
      }
  }

  private func setStatusItemVisible(_ visible: Bool) {
    if !visible {
      if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
      statusItem = nil
      return
    }
    guard statusItem == nil else { return }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.button?.image = locatorMenuBarImage
    item.button?.toolTip = L10n.text("Mouse Locator")

    let menu = NSMenu()
    menu.delegate = self
    menu.addItem(
      withTitle: L10n.text("Mouse Tail"), action: #selector(toggleTail), keyEquivalent: "")
    menu.addItem(
      withTitle: L10n.text("Idle Pulse"), action: #selector(toggleSonar), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(
      withTitle: L10n.text("Settings…"), action: #selector(openSettings), keyEquivalent: ",")
    menu.addItem(.separator())
    menu.addItem(
      withTitle: L10n.text("Quit Mouse Locator"), action: #selector(quit), keyEquivalent: "q")
    menu.items.forEach { $0.target = self }
    item.menu = menu
    statusItem = item
  }

  @objc private func toggleTail() {
    LocatorSettings.shared.tailEnabled.toggle()
  }

  @objc private func toggleSonar() {
    LocatorSettings.shared.sonarEnabled.toggle()
  }

  @objc private func openSettings() {
    NSWorkspace.shared.open(
      FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/PreferencePanes/MouseLocator.prefPane")
    )
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }

  private func setLaunchAtLogin(_ enabled: Bool) {
    let service = SMAppService.mainApp
    do {
      if enabled {
        if service.status == .notRegistered {
          try service.register()
        }
      } else if service.status == .enabled || service.status == .requiresApproval {
        try service.unregister()
      }
    } catch {
      let alert = NSAlert(error: error)
      alert.messageText = enabled
        ? L10n.text("Couldn’t Enable Launch at Login")
        : L10n.text("Couldn’t Disable Launch at Login")
      alert.runModal()
    }

    if enabled, service.status == .requiresApproval {
      SMAppService.openSystemSettingsLoginItems()
    }
  }
}

extension AppDelegate: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    menu.items[0].state = LocatorSettings.shared.tailEnabled ? .on : .off
    menu.items[1].state = LocatorSettings.shared.sonarEnabled ? .on : .off
  }
}

@MainActor
private final class OverlayController: NSObject {
  private var panels: [NSPanel] = []
  private var points: [TrailPoint] = []
  private var timer: Timer?
  private var lastMovementTime = ProcessInfo.processInfo.systemUptime
  private var lastPosition = NSEvent.mouseLocation
  private var sonarPosition: NSPoint?
  private var sonarStartTime: TimeInterval?

  func start() {
    rebuildPanels()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(rebuildPanels),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )

    timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.tick()
      }
    }
    timer?.tolerance = 0.004
  }

  @objc private func rebuildPanels() {
    panels.forEach { $0.close() }
    panels = NSScreen.screens.map(makePanel)
  }

  private func makePanel(for screen: NSScreen) -> NSPanel {
    let panel = NSPanel(
      contentRect: screen.frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    panel.backgroundColor = .clear
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.contentView = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
    panel.hasShadow = false
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.isOpaque = false
    panel.isReleasedWhenClosed = false
    panel.level = .statusBar
    panel.orderFrontRegardless()
    return panel
  }

  private func tick() {
    let settings = LocatorSettings.shared
    let now = ProcessInfo.processInfo.systemUptime
    let position = NSEvent.mouseLocation

    if position != lastPosition {
      let idleDuration = now - lastMovementTime
      lastPosition = position
      lastMovementTime = now
      if settings.sonarEnabled,
        idleDuration >= settings.sonarDelay
      {
        sonarPosition = position
        sonarStartTime = now
      }
      if settings.tailEnabled {
        points.append(TrailPoint(position: position, time: now))
      }
    }

    points.removeAll { now - $0.time >= EffectTiming.trailLifetime }
    if !settings.tailEnabled {
      points.removeAll()
    }

    if !settings.sonarEnabled {
      sonarPosition = nil
      sonarStartTime = nil
    } else if sonarStartTime != nil {
      sonarPosition = position
    }
    let sonarProgress = sonarStartTime.flatMap { EffectTiming.sonarProgress(elapsed: now - $0) }
    if sonarStartTime != nil, sonarProgress == nil {
      sonarPosition = nil
      sonarStartTime = nil
    }
    panels.forEach { panel in
      guard let view = panel.contentView as? OverlayView else { return }
      let frameState = OverlayFrame(
        points: points,
        tailColor: .locatorColor(settings.tailColor),
        tailDotsEnabled: settings.tailDotsEnabled,
        tailGap: settings.tailGap,
        tailLineWidth: settings.tailThickness,
        tailRainbow: settings.tailRainbow,
        tailSmoothing: settings.tailSmoothing,
        now: now,
        sonarPosition: sonarPosition,
        sonarProgress: sonarProgress,
        sonarColor: .locatorColor(settings.sonarColor),
        sonarRainbow: settings.sonarRainbow,
        sonarSize: settings.sonarSize,
        sonarLineWidth: settings.sonarThickness
      )
      if view.frameState.isVisible || frameState.isVisible {
        view.frameState = frameState
        view.needsDisplay = true
      }
    }
  }
}

private struct TrailPoint {
  let position: NSPoint
  let time: TimeInterval
}

private struct OverlayFrame {
  let points: [TrailPoint]
  let tailColor: NSColor
  let tailDotsEnabled: Bool
  let tailGap: CGFloat
  let tailLineWidth: CGFloat
  let tailRainbow: Bool
  let tailSmoothing: String
  let now: TimeInterval
  let sonarPosition: NSPoint?
  let sonarProgress: Double?
  let sonarColor: NSColor
  let sonarRainbow: Bool
  let sonarSize: CGFloat
  let sonarLineWidth: CGFloat

  var isVisible: Bool {
    points.count > 1 || sonarProgress != nil
  }
}

private final class OverlayView: NSView {
  var frameState = OverlayFrame(
    points: [],
    tailColor: .controlAccentColor,
    tailDotsEnabled: false,
    tailGap: 16,
    tailLineWidth: 3,
    tailRainbow: false,
    tailSmoothing: "bezier",
    now: 0,
    sonarPosition: nil,
    sonarProgress: nil,
    sonarColor: .controlAccentColor,
    sonarRainbow: false,
    sonarSize: 180,
    sonarLineWidth: 3
  )

  override var isOpaque: Bool { false }

  override func draw(_ dirtyRect: NSRect) {
    guard let origin = window?.frame.origin else { return }

    if frameState.points.count > 1 {
      NSGraphicsContext.saveGraphicsState()
      if frameState.tailGap > 0, let cursor = frameState.points.last?.position {
        let radius = frameState.tailGap + frameState.tailLineWidth / 2
        let clipPath = NSBezierPath(rect: bounds)
        clipPath.appendOval(
          in: NSRect(
            x: cursor.x - origin.x - radius,
            y: cursor.y - origin.y - radius,
            width: radius * 2,
            height: radius * 2
          )
        )
        clipPath.windingRule = .evenOdd
        clipPath.addClip()
      }
      let totalDistance = zip(frameState.points, frameState.points.dropFirst()).reduce(0) {
        $0 + $1.0.position.distance(to: $1.1.position)
      }
      var distance: CGFloat = 0
      for index in 1..<frameState.points.count {
        let previous = frameState.points[index - 1]
        let point = frameState.points[index]
        let startDistance = distance
        distance += previous.position.distance(to: point.position)
        let opacity = EffectTiming.trailOpacity(age: frameState.now - point.time)
        let start = previous.position - origin
        let end = point.position - origin
        let path = NSBezierPath()
        path.lineCapStyle = frameState.tailDotsEnabled ? .round : .butt
        path.lineJoinStyle = .round
        path.lineWidth = frameState.tailLineWidth
        path.move(to: start)
        if frameState.tailSmoothing == "none" {
          path.line(to: end)
        } else {
          let before = frameState.points[max(0, index - 2)].position
          let after = frameState.points[min(frameState.points.count - 1, index + 1)].position
          let controlX = TailGeometry.bezierControlValues(
            previous: before.x,
            start: previous.position.x,
            end: point.position.x,
            following: after.x
          )
          let controlY = TailGeometry.bezierControlValues(
            previous: before.y,
            start: previous.position.y,
            end: point.position.y,
            following: after.y
          )
          path.curve(
            to: end,
            controlPoint1: NSPoint(x: controlX.first, y: controlY.first) - origin,
            controlPoint2: NSPoint(x: controlX.second, y: controlY.second) - origin
          )
        }
        if frameState.tailRainbow {
          let startColor = NSColor(
            calibratedHue: totalDistance > 0 ? startDistance / totalDistance : 0,
            saturation: 0.9,
            brightness: 1,
            alpha: EffectTiming.trailOpacity(age: frameState.now - previous.time) * 0.85
          )
          let endColor = NSColor(
            calibratedHue: totalDistance > 0 ? distance / totalDistance : 0,
            saturation: 0.9,
            brightness: 1,
            alpha: opacity * 0.85
          )
          stroke(path, from: start, to: end, colors: [startColor, endColor])
        } else {
          frameState.tailColor.withAlphaComponent(opacity * 0.85).setStroke()
          path.stroke()
        }
      }
      NSGraphicsContext.restoreGraphicsState()
    }

    if let position = frameState.sonarPosition, let progress = frameState.sonarProgress {
      let diameter = 24 + (frameState.sonarSize - 24) * progress
      let center = position - origin
      let path = NSBezierPath()
      path.appendOval(
        in: NSRect(
          x: center.x - diameter / 2,
          y: center.y - diameter / 2,
          width: diameter,
          height: diameter
        )
      )
      path.lineCapStyle = .round
      path.lineWidth = frameState.sonarLineWidth
      let color = frameState.sonarRainbow
        ? NSColor(
          calibratedHue: CGFloat(progress),
          saturation: 0.9,
          brightness: 1,
          alpha: 1
        )
        : frameState.sonarColor
      color.withAlphaComponent((1 - progress) * 0.9).setStroke()
      path.stroke()
    }
  }

  private func stroke(
    _ path: NSBezierPath,
    from start: NSPoint,
    to end: NSPoint,
    colors: [NSColor]
  ) {
    guard
      start != end,
      let context = NSGraphicsContext.current?.cgContext,
      let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: colors.map(\.cgColor) as CFArray,
        locations: [0, 1]
      )
    else {
      colors.last?.setStroke()
      path.stroke()
      return
    }

    context.saveGState()
    context.addPath(path.cgPath)
    context.setLineWidth(path.lineWidth)
    context.setLineCap(frameState.tailDotsEnabled ? .round : .butt)
    context.setLineJoin(.round)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(
      gradient,
      start: start,
      end: end,
      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )
    context.restoreGState()
  }
}

private extension NSPoint {
  static func - (lhs: NSPoint, rhs: NSPoint) -> NSPoint {
    NSPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }

  func distance(to other: NSPoint) -> CGFloat {
    hypot(x - other.x, y - other.y)
  }
}
