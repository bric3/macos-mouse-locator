import Foundation

public enum EffectTiming {
  public static let sonarDuration: TimeInterval = 1.6
  public static let trailLifetime: TimeInterval = 0.55

  public static func sonarProgress(elapsed: TimeInterval) -> Double? {
    guard elapsed >= 0, elapsed < sonarDuration else { return nil }
    return elapsed / sonarDuration
  }

  public static func trailOpacity(age: TimeInterval) -> Double {
    max(0, min(1, 1 - age / trailLifetime))
  }
}
