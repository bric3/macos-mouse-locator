// Copyright 2026 Brice Dutheil
// SPDX-License-Identifier: MPL-2.0

public enum FocusedAppPolicy {
  public static func shouldPause(
    bundleIdentifier: String?,
    category: String?,
    pauseWhenGameFocused: Bool,
    excludedApplicationBundleIdentifiers: [String]
  ) -> Bool {
    if let bundleIdentifier,
      excludedApplicationBundleIdentifiers.contains(bundleIdentifier)
    {
      return true
    }
    guard pauseWhenGameFocused, let category else { return false }
    return category == "public.app-category.games"
      || (category.hasPrefix("public.app-category.") && category.hasSuffix("-games"))
  }
}
