import MouseLocatorCore

precondition(EffectTiming.trailOpacity(age: 0) == 1)
precondition(EffectTiming.trailOpacity(age: EffectTiming.trailLifetime / 2) == 0.5)
precondition(EffectTiming.trailOpacity(age: EffectTiming.trailLifetime) == 0)
print("Effect timing checks passed")

