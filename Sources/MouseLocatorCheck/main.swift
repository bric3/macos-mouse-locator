import MouseLocatorCore

func approximatelyEqual(_ value: Double?, _ expected: Double) -> Bool {
  value.map { abs($0 - expected) < 0.000_001 } ?? false
}

precondition(EffectTiming.trailOpacity(age: 0) == 1)
precondition(EffectTiming.trailOpacity(age: EffectTiming.trailLifetime / 2) == 0.5)
precondition(EffectTiming.trailOpacity(age: EffectTiming.trailLifetime) == 0)
precondition(EffectTiming.sonarProgress(idleDuration: 2.9, threshold: 3) == nil)
precondition(EffectTiming.sonarProgress(idleDuration: 3, threshold: 3) == 0)
precondition(approximatelyEqual(EffectTiming.sonarProgress(idleDuration: 3.8, threshold: 3), 0.5))
precondition(
  approximatelyEqual(
    EffectTiming.sonarProgress(idleDuration: EffectTiming.sonarCycle, threshold: 0),
    0
  )
)
print("Effect timing checks passed")
