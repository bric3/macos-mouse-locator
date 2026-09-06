import Foundation

public enum EffectTiming {
  public static let sonarCycle: TimeInterval = 1.6
  public static let trailLifetime: TimeInterval = 0.55

  public static func sonarProgress(
    idleDuration: TimeInterval,
    threshold: TimeInterval
  ) -> Double? {
    guard idleDuration >= threshold else { return nil }
    return (idleDuration - threshold).truncatingRemainder(dividingBy: sonarCycle) / sonarCycle
  }

  public static func trailOpacity(age: TimeInterval) -> Double {
    max(0, min(1, 1 - age / trailLifetime))
  }
}
