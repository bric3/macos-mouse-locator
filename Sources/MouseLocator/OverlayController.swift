import AppKit
import MouseLocatorCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var overlayController: OverlayController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    overlayController = OverlayController()
    overlayController?.start()
  }
}

@MainActor
private final class OverlayController: NSObject {
  private var panels: [NSPanel] = []
  private var points: [TrailPoint] = []
  private var timer: Timer?
  private var lastPosition = NSEvent.mouseLocation

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
    panel.contentView = TrailView(frame: NSRect(origin: .zero, size: screen.frame.size))
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
    let defaults = UserDefaults.standard
    let now = ProcessInfo.processInfo.systemUptime
    let position = NSEvent.mouseLocation
    let tailEnabled = defaults.bool(forKey: LocatorDefaults.tailEnabled)

    if position != lastPosition {
      lastPosition = position
      if tailEnabled {
        points.append(TrailPoint(position: position, time: now))
      }
    }

    points.removeAll { now - $0.time >= EffectTiming.trailLifetime }
    if !tailEnabled {
      points.removeAll()
    }

    let lineWidth = defaults.double(forKey: LocatorDefaults.tailSize)
    panels.forEach { panel in
      guard let view = panel.contentView as? TrailView else { return }
      view.frameState = TrailFrame(points: points, lineWidth: lineWidth, now: now)
      view.needsDisplay = true
    }
  }
}

private struct TrailPoint {
  let position: NSPoint
  let time: TimeInterval
}

private struct TrailFrame {
  let points: [TrailPoint]
  let lineWidth: CGFloat
  let now: TimeInterval
}

private final class TrailView: NSView {
  var frameState = TrailFrame(points: [], lineWidth: 8, now: 0)

  override var isOpaque: Bool { false }

  override func draw(_ dirtyRect: NSRect) {
    guard frameState.points.count > 1, let origin = window?.frame.origin else { return }

    for index in 1..<frameState.points.count {
      let previous = frameState.points[index - 1]
      let point = frameState.points[index]
      let opacity = EffectTiming.trailOpacity(age: frameState.now - point.time)
      let path = NSBezierPath()
      path.lineCapStyle = .round
      path.lineJoinStyle = .round
      path.lineWidth = frameState.lineWidth
      path.move(to: previous.position - origin)
      path.line(to: point.position - origin)
      NSColor.controlAccentColor.withAlphaComponent(opacity * 0.85).setStroke()
      path.stroke()
    }
  }
}

private extension NSPoint {
  static func - (lhs: NSPoint, rhs: NSPoint) -> NSPoint {
    NSPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
  }
}

