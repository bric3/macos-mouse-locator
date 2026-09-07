// Copyright 2026 Brice Dutheil
// SPDX-License-Identifier: MPL-2.0

import Foundation
import MouseLocatorCore

func approximatelyEqual(_ value: Double?, _ expected: Double) -> Bool {
  value.map { abs($0 - expected) < 0.000_001 } ?? false
}

precondition(EffectTiming.trailOpacity(age: 0) == 1)
precondition(EffectTiming.trailOpacity(age: EffectTiming.trailLifetime / 2) == 0.5)
precondition(EffectTiming.trailOpacity(age: EffectTiming.trailLifetime) == 0)
precondition(EffectTiming.sonarProgress(elapsed: -0.1) == nil)
precondition(EffectTiming.sonarProgress(elapsed: 0) == 0)
precondition(approximatelyEqual(EffectTiming.sonarProgress(elapsed: 1.5), 0.5))
precondition(EffectTiming.sonarProgress(elapsed: EffectTiming.sonarDuration) == nil)
precondition(approximatelyEqual(EffectTiming.sonarProgress(elapsed: 0.75, speed: 2), 0.5))
precondition(EffectTiming.sonarProgress(elapsed: 1.5, speed: 2) == nil)
precondition(EffectTiming.sonarProgress(elapsed: 1, speed: 0) == nil)
precondition(
  EffectTiming.tailActivationEnd(now: 10, idleDuration: 2.9, delay: 3) == nil
)
precondition(
  EffectTiming.tailActivationEnd(now: 10, idleDuration: 3, delay: 3) == 13
)

let controlValues = TailGeometry.bezierControlValues(
  previous: 0,
  start: 6,
  end: 12,
  following: 18
)
precondition(controlValues.first == 8)
precondition(controlValues.second == 10)

let home = URL(fileURLWithPath: "/Users/test", isDirectory: true)
precondition(
  ConfigurationLocation.settingsURL(xdgConfigHome: nil, homeDirectory: home).path
    == "/Users/test/.config/mouse-locator/settings.json"
)
precondition(
  ConfigurationLocation.settingsURL(xdgConfigHome: "/tmp/config", homeDirectory: home).path
    == "/tmp/config/mouse-locator/settings.json"
)
precondition(
  ConfigurationLocation.settingsURL(xdgConfigHome: "relative", homeDirectory: home).path
    == "/Users/test/.config/mouse-locator/settings.json"
)
print("Mouse Locator checks passed")
