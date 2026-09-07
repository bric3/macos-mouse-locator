// Copyright 2026 Brice Dutheil
// SPDX-License-Identifier: MPL-2.0

import Foundation

public enum EffectTiming {
  public static let sonarDuration: TimeInterval = 3
  public static let tailActivationDuration: TimeInterval = 3
  public static let trailLifetime: TimeInterval = 0.55

  public static func sonarProgress(elapsed: TimeInterval, speed: Double = 1) -> Double? {
    let scaledElapsed = elapsed * speed
    guard speed > 0, scaledElapsed >= 0, scaledElapsed < sonarDuration else { return nil }
    return scaledElapsed / sonarDuration
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
