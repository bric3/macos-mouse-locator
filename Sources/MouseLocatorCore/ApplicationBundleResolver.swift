// Copyright 2026 Brice Dutheil
// SPDX-License-Identifier: MPL-2.0

import Foundation

public enum ApplicationBundleResolver {
  public static func bundleIdentifier(
    for applicationURL: URL,
    steamDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/Steam", isDirectory: true)
  ) -> String? {
    guard let bundle = Bundle(url: applicationURL) else { return nil }
    guard let executable = bundle.executableURL, executable.lastPathComponent == "run.sh",
      let size = try? executable.resourceValues(forKeys: [.fileSizeKey]).fileSize,
      size <= 64_000,
      let script = try? String(contentsOf: executable, encoding: .utf8)
    else {
      return bundle.bundleIdentifier.flatMap { $0.isEmpty ? nil : $0 }
    }
    let commands = script.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    guard commands.count == 1,
      let appID = captures(
        #"^open[ \t]+(["']?)steam://(?:run|rungameid)/([0-9]+)\1$"#,
        in: commands[0], group: 2
      ).first
    else {
      return bundle.bundleIdentifier.flatMap { $0.isEmpty ? nil : $0 }
    }
    guard let number = UInt32(appID), number > 0 else { return nil }

    let libraryFolders = (try? String(
      contentsOf: steamDirectory.appendingPathComponent("steamapps/libraryfolders.vdf"),
      encoding: .utf8
    )) ?? ""
    let libraries = [steamDirectory] + values("path", in: libraryFolders)
      .filter { NSString(string: $0).isAbsolutePath }
      .map { URL(fileURLWithPath: $0, isDirectory: true) }
    var identifiers = Set<String>()
    for library in Set(libraries) {
      let steamapps = library.appendingPathComponent("steamapps", isDirectory: true)
      guard let manifest = try? String(
        contentsOf: steamapps.appendingPathComponent("appmanifest_\(number).acf"),
        encoding: .utf8
      ),
        values("appid", in: manifest) == [String(number)],
        let directory = values("installdir", in: manifest).first,
        !directory.isEmpty, directory != ".", directory != "..", !directory.contains("/"),
        let apps = try? FileManager.default.contentsOfDirectory(
          at: steamapps.appendingPathComponent("common/\(directory)", isDirectory: true),
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )
      else { continue }

      // ponytail: resolve one top-level game app; select its .app for nested/ambiguous installs.
      for app in apps where app.pathExtension.lowercased() == "app" {
        if let identifier = Bundle(url: app)?.bundleIdentifier, !identifier.isEmpty {
          identifiers.insert(identifier)
        }
      }
    }
    return identifiers.count == 1 ? identifiers.first : nil
  }

  // ponytail: read quoted VDF fields only; use a KeyValues parser if Steam changes their format.
  private static func values(_ key: String, in source: String) -> [String] {
    captures(#""\#(key)"\s+("(?:\\.|[^"\\])*")"#, in: source).compactMap {
      try? JSONDecoder().decode(String.self, from: Data($0.utf8))
    }
  }

  private static func captures(_ pattern: String, in source: String, group: Int = 1) -> [String] {
    guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
    return expression.matches(in: source, range: NSRange(source.startIndex..., in: source))
      .compactMap {
        guard let range = Range($0.range(at: group), in: source) else { return nil }
        return String(source[range])
      }
  }
}
