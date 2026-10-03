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
precondition(
  approximatelyEqual(
    EffectTiming.trailSpeedFactor(distance: 18, duration: 0.02),
    0.75
  )
)
precondition(EffectTiming.trailSpeedFactor(distance: 60, duration: 0.02) == 1)
precondition(EffectTiming.trailSpeedFactor(distance: 18, duration: 0) == 1)
precondition(EffectTiming.trailShadeFactor(speedFactor: 0.5, age: 0) == 1)
precondition(
  approximatelyEqual(
    EffectTiming.trailShadeFactor(speedFactor: 0.5, age: EffectTiming.trailLifetime / 2),
    0.75
  )
)
precondition(
  EffectTiming.trailShadeFactor(speedFactor: 0.5, age: EffectTiming.trailLifetime) == 0.5
)
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

var modifierTap = ModifierTapDetector()
precondition(!modifierTap.update(isPressed: true, isAlone: true, at: 1, maximumDuration: 0.35))
precondition(modifierTap.update(isPressed: false, isAlone: true, at: 1.3, maximumDuration: 0.35))
precondition(!modifierTap.update(isPressed: true, isAlone: true, at: 2, maximumDuration: 0.35))
precondition(!modifierTap.update(isPressed: false, isAlone: true, at: 2.4, maximumDuration: 0.35))
precondition(!modifierTap.update(isPressed: true, isAlone: true, at: 3, maximumDuration: 0.35))
modifierTap.cancel()
precondition(!modifierTap.update(isPressed: false, isAlone: true, at: 3.1, maximumDuration: 0.35))
precondition(!modifierTap.update(isPressed: true, isAlone: true, at: 4, maximumDuration: 0.35))
precondition(!modifierTap.update(isPressed: true, isAlone: false, at: 4.1, maximumDuration: 0.35))
precondition(!modifierTap.update(isPressed: false, isAlone: false, at: 4.2, maximumDuration: 0.35))
precondition(!modifierTap.update(isPressed: true, isAlone: true, at: 5, maximumDuration: 0.35))
modifierTap.reset()
precondition(!modifierTap.update(isPressed: false, isAlone: true, at: 5.1, maximumDuration: 0.35))

let excludedApp = "com.example.Game"
for (identifier, category, automatic, expected) in [
  (excludedApp, nil, false, true),
  (excludedApp, "public.app-category.utilities", true, true),
  ("com.example.Other", nil, false, false),
  ("com.example.Other", "public.app-category.games", false, false),
  ("com.example.Other", "public.app-category.games", true, true),
  ("com.example.Other", "public.app-category.adventure-games", true, true),
  ("com.example.Other", "public.app-category.role-playing-games", true, true),
  ("com.example.Other", "public.app-category.utilities", true, false),
  ("com.example.Other", "com.example.adventure-games", true, false),
  ("com.example.Other", nil, true, false),
  (nil, nil, true, false),
  (nil, "public.app-category.games", true, true),
] as [(String?, String?, Bool, Bool)] {
  precondition(
    FocusedAppPolicy.shouldPause(
      bundleIdentifier: identifier,
      category: category,
      pauseWhenGameFocused: automatic,
      excludedApplicationBundleIdentifiers: [excludedApp]
    ) == expected
  )
}
precondition(
  !FocusedAppPolicy.shouldPause(
    bundleIdentifier: excludedApp,
    category: nil,
    pauseWhenGameFocused: false,
    excludedApplicationBundleIdentifiers: []
  )
)

let home = URL(fileURLWithPath: "/Users/test", isDirectory: true)
precondition(
  ConfigurationLocation.settingsURL(xdgConfigHome: nil, homeDirectory: home).path
    == "/Users/test/.config/mouse-locator/settings.toml"
)
precondition(
  ConfigurationLocation.settingsURL(xdgConfigHome: "/tmp/config", homeDirectory: home).path
    == "/tmp/config/mouse-locator/settings.toml"
)
precondition(
  ConfigurationLocation.settingsURL(xdgConfigHome: "relative", homeDirectory: home).path
    == "/Users/test/.config/mouse-locator/settings.toml"
)
precondition(
  ConfigurationLocation.legacySettingsURL(xdgConfigHome: nil, homeDirectory: home).path
    == "/Users/test/.config/mouse-locator/settings.json"
)

let tomlSource = try FlatTOML.document(
  header: ["Settings", "Key names are not stable yet."],
  fields: [
    ("enabled", "true"),
    ("duration", "0.35"),
    ("modifier", FlatTOML.quoted("control")),
    ("excludedApps", FlatTOML.array([excludedApp, "com.example.Other"])),
    ("emptyApps", FlatTOML.array([])),
    ("escapedStrings", FlatTOML.array(["quote\"", "slash\\", "line\nbreak"])),
  ]
)
let toml = try FlatTOML(tomlSource)
let tomlEnabled = try toml.bool("enabled")
let tomlDuration = try toml.double("duration")
let tomlModifier = try toml.string("modifier")
let tomlExcludedApps = try toml.strings("excludedApps")
let tomlEmptyApps = try toml.strings("emptyApps")
let tomlMissingApps = try toml.strings("missingApps")
let tomlEscapedStrings = try toml.strings("escapedStrings")
precondition(tomlEnabled == true)
precondition(tomlDuration == 0.35)
precondition(tomlModifier == "control")
precondition(tomlExcludedApps == [excludedApp, "com.example.Other"])
precondition(tomlEmptyApps == [])
precondition(tomlMissingApps == nil)
precondition(tomlEscapedStrings == ["quote\"", "slash\\", "line\nbreak"])
precondition(tomlSource.contains("# Key names are not stable yet."))
do {
  _ = try FlatTOML("enabled = maybe").bool("enabled")
  preconditionFailure("Invalid TOML boolean was accepted")
} catch {}
for invalidArray in ["true", "\"app\"", "[1]", "[\"app\", false]", "[\"app\""] {
  do {
    _ = try FlatTOML("apps = \(invalidArray)").strings("apps")
    preconditionFailure("Invalid TOML string array was accepted")
  } catch {}
}
func checkApplicationBundleResolution() throws {
  let files = FileManager.default
  let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
  try files.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? files.removeItem(at: root) }

  func app(_ path: String, identifier: String? = nil, script: String? = nil) throws -> URL {
    let url = root.appendingPathComponent(path, isDirectory: true)
    let contents = url.appendingPathComponent("Contents/MacOS", isDirectory: true)
    try files.createDirectory(at: contents, withIntermediateDirectories: true)
    var info = ["CFBundlePackageType": "APPL"]
    if let identifier { info["CFBundleIdentifier"] = identifier }
    if let script {
      info["CFBundleExecutable"] = "run.sh"
      let executable = contents.appendingPathComponent("run.sh")
      try script.write(to: executable, atomically: true, encoding: .utf8)
      try files.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    }
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
      .write(to: url.appendingPathComponent("Contents/Info.plist"))
    return url
  }

  let steam = root.appendingPathComponent("Steam", isDirectory: true)
  let steamapps = steam.appendingPathComponent("steamapps", isDirectory: true)
  let game = try app("Steam/steamapps/common/Test Game/Game.app", identifier: "dev.test.Game")
  let shortcut = try app(
    "Shortcut.app", identifier: "dev.test.Shortcut",
    script: "#!/bin/bash\n# autogenerated file - do not edit\n\nopen steam://run/1569580\n"
  )
  let scriptURL = shortcut.appendingPathComponent("Contents/MacOS/run.sh")
  let manifestURL = steamapps.appendingPathComponent("appmanifest_1569580.acf")
  try "\"AppState\"\n{\n\"appid\" \"1569580\"\n\"installdir\" \"Test Game\"\n}\n"
    .write(to: manifestURL, atomically: true, encoding: .utf8)

  func resolve(_ url: URL) -> String? {
    ApplicationBundleResolver.bundleIdentifier(for: url, steamDirectory: steam)
  }
  precondition(resolve(game) == "dev.test.Game")
  precondition(resolve(shortcut) == "dev.test.Game")
  // Helper apps inside the game bundle must not make its install ambiguous.
  _ = try app(
    "Steam/steamapps/common/Test Game/Game.app/Contents/Helpers/Helper.app",
    identifier: "dev.test.Helper"
  )
  precondition(resolve(shortcut) == "dev.test.Game")
  for command in ["open \"steam://run/1569580\"", "open 'steam://rungameid/1569580'"] {
    try command.write(to: scriptURL, atomically: true, encoding: .utf8)
    precondition(resolve(shortcut) == "dev.test.Game")
  }
  for id in ["0", "4294967296", "123456"] {
    try "open steam://run/\(id)".write(to: scriptURL, atomically: true, encoding: .utf8)
    precondition(resolve(shortcut) == nil)
  }
  let unsupported = try app("Unsupported.app", script: "# open steam://run/1569580\n")
  precondition(resolve(unsupported) == nil)
  let unsafe = try app(
    "Custom.app", script: "open steam://run/1569580\ntouch '\(root.path)/executed'\n"
  )
  precondition(resolve(unsafe) == nil)
  precondition(!files.fileExists(atPath: root.appendingPathComponent("executed").path))
  try "open steam://run/1569580".write(to: scriptURL, atomically: true, encoding: .utf8)
  let other = try app("Steam/steamapps/common/Test Game/Other.app", identifier: "dev.test.Other")
  precondition(resolve(shortcut) == nil)
  try files.removeItem(at: other)

  // Resolve a game moved to another library, including escaped quotes/backslashes in its path.
  let external = root.appendingPathComponent("External \"Library\" \\", isDirectory: true)
  _ = try app(
    "External \"Library\" \\/steamapps/common/Test Game/Game.app", identifier: "dev.test.Game"
  )
  let externalManifest = external.appendingPathComponent("steamapps/appmanifest_1569580.acf")
  try files.copyItem(at: manifestURL, to: externalManifest)
  try files.removeItem(at: manifestURL)
  try "\"libraryfolders\"\n{\n\"1\"\n{\n\"path\" \(FlatTOML.quoted(external.path))\n}\n}\n"
    .write(to: steamapps.appendingPathComponent("libraryfolders.vdf"), atomically: true, encoding: .utf8)
  precondition(resolve(shortcut) == "dev.test.Game")
  for manifest in [
    "\"appid\" \"1\"\n\"installdir\" \"Test Game\"",
    "\"appid\" \"1569580\"\n\"installdir\" \"../Test Game\"",
    "\"appid\" \"1569580\"\n\"installdir\" \"Missing\"",
  ] {
    try manifest.write(to: externalManifest, atomically: true, encoding: .utf8)
    precondition(resolve(shortcut) == nil)
  }
}
try checkApplicationBundleResolution()

if let index = CommandLine.arguments.firstIndex(of: "--resolve-app"),
  CommandLine.arguments.indices.contains(index + 1)
{
  let url = URL(fileURLWithPath: CommandLine.arguments[index + 1])
  guard let identifier = ApplicationBundleResolver.bundleIdentifier(for: url) else {
    preconditionFailure("Could not resolve \(url.path)")
  }
  print("Resolved \(url.lastPathComponent): \(identifier)")
}
print("Mouse Locator checks passed")
