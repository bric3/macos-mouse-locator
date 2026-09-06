import AppKit
import MouseLocatorCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var overlayController: OverlayController?

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
  }

  private func setLaunchAtLogin(_ enabled: Bool) {
    let service = SMAppService.mainApp
    do {
      if service.status == .enabled || service.status == .requiresApproval {
        try service.unregister()
      }
      if enabled {
        try service.register()
      }
    } catch {
      let alert = NSAlert(error: error)
      alert.messageText = enabled
        ? "Couldn’t Enable Launch at Login"
        : "Couldn’t Disable Launch at Login"
      alert.runModal()
    }

    if enabled, service.status == .requiresApproval {
      SMAppService.openSystemSettingsLoginItems()
    }
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
        tailLineWidth: settings.tailThickness,
        tailRainbow: settings.tailRainbow,
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
  let tailLineWidth: CGFloat
  let tailRainbow: Bool
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
    tailLineWidth: 8,
    tailRainbow: false,
    now: 0,
    sonarPosition: nil,
    sonarProgress: nil,
    sonarColor: .controlAccentColor,
    sonarRainbow: false,
    sonarSize: 180,
    sonarLineWidth: 8
  )

  override var isOpaque: Bool { false }

  override func draw(_ dirtyRect: NSRect) {
    guard let origin = window?.frame.origin else { return }

    if frameState.points.count > 1 {
      let totalDistance = zip(frameState.points, frameState.points.dropFirst()).reduce(0) {
        $0 + $1.0.position.distance(to: $1.1.position)
      }
      var distance: CGFloat = 0
      for index in 1..<frameState.points.count {
        let previous = frameState.points[index - 1]
        let point = frameState.points[index]
        distance += previous.position.distance(to: point.position)
        let opacity = EffectTiming.trailOpacity(age: frameState.now - point.time)
        let path = NSBezierPath()
        path.lineCapStyle = frameState.tailDotsEnabled ? .round : .butt
        path.lineJoinStyle = .round
        path.lineWidth = frameState.tailLineWidth
        path.move(to: previous.position - origin)
        path.line(to: point.position - origin)
        let color = frameState.tailRainbow
          ? NSColor(
            calibratedHue: totalDistance > 0 ? distance / totalDistance : 0,
            saturation: 0.9,
            brightness: 1,
            alpha: 1
          )
          : frameState.tailColor
        color.withAlphaComponent(opacity * 0.85).setStroke()
        path.stroke()
      }
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
}

private extension NSPoint {
  static func - (lhs: NSPoint, rhs: NSPoint) -> NSPoint {
    NSPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }

  func distance(to other: NSPoint) -> CGFloat {
    hypot(x - other.x, y - other.y)
  }
}
