import Foundation

public enum EffectTiming {
  public static let trailLifetime: TimeInterval = 0.55

  public static func trailOpacity(age: TimeInterval) -> Double {
    max(0, min(1, 1 - age / trailLifetime))
  }
}

