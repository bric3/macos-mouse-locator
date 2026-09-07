import Foundation

public enum EffectTiming {
  public static let sonarDuration: TimeInterval = 3
  public static let tailActivationDuration: TimeInterval = 3
  public static let trailLifetime: TimeInterval = 0.55

  public static func sonarProgress(elapsed: TimeInterval) -> Double? {
    guard elapsed >= 0, elapsed < sonarDuration else { return nil }
    return elapsed / sonarDuration
  }

  public static func sonarExpansionProgress(lifetimeProgress: Double, speed: Double) -> Double {
    max(0, min(1, lifetimeProgress * speed))
  }

  public static func tailActivationEnd(
    now: TimeInterval,
    idleDuration: TimeInterval,
    delay: TimeInterval
  ) -> TimeInterval? {
    idleDuration >= delay ? now + tailActivationDuration : nil
  }

  public static func trailOpacity(age: TimeInterval) -> Double {
    max(0, min(1, 1 - age / trailLifetime))
  }
}

public enum TailGeometry {
  public static func bezierControlValues(
    previous: Double,
    start: Double,
    end: Double,
    following: Double
  ) -> (first: Double, second: Double) {
    (
      start + (end - previous) / 6,
      end - (following - start) / 6
    )
  }
}

public enum ConfigurationLocation {
  public static func settingsURL(xdgConfigHome: String?, homeDirectory: URL) -> URL {
    let configHome = xdgConfigHome.flatMap { path in
      guard !path.isEmpty, NSString(string: path).isAbsolutePath else { return nil }
      return URL(fileURLWithPath: path, isDirectory: true)
    } ?? homeDirectory.appendingPathComponent(".config", isDirectory: true)

    return configHome
      .appendingPathComponent("mouse-locator", isDirectory: true)
      .appendingPathComponent("settings.json")
  }
}
