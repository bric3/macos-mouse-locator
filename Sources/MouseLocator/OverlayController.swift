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
        tailLineWidth: settings.tailThickness,
        now: now,
        sonarPosition: sonarPosition,
        sonarProgress: sonarProgress,
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
  let tailLineWidth: CGFloat
  let now: TimeInterval
  let sonarPosition: NSPoint?
  let sonarProgress: Double?
  let sonarSize: CGFloat
  let sonarLineWidth: CGFloat

  var isVisible: Bool {
    points.count > 1 || sonarProgress != nil
  }
}

private final class OverlayView: NSView {
  var frameState = OverlayFrame(
    points: [],
    tailLineWidth: 8,
    now: 0,
    sonarPosition: nil,
    sonarProgress: nil,
    sonarSize: 180,
    sonarLineWidth: 8
  )

  override var isOpaque: Bool { false }

  override func draw(_ dirtyRect: NSRect) {
    guard let origin = window?.frame.origin else { return }

    if frameState.points.count > 1 {
      for index in 1..<frameState.points.count {
        let previous = frameState.points[index - 1]
        let point = frameState.points[index]
        let opacity = EffectTiming.trailOpacity(age: frameState.now - point.time)
        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = frameState.tailLineWidth
        path.move(to: previous.position - origin)
        path.line(to: point.position - origin)
        NSColor.controlAccentColor.withAlphaComponent(opacity * 0.85).setStroke()
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
      NSColor.controlAccentColor.withAlphaComponent((1 - progress) * 0.9).setStroke()
      path.stroke()
    }
  }
}

private extension NSPoint {
  static func - (lhs: NSPoint, rhs: NSPoint) -> NSPoint {
    NSPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }
}
