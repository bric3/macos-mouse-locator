// Copyright 2026 Brice Dutheil
// SPDX-License-Identifier: MPL-2.0

import Foundation

public struct FlatTOML {
  private let values: [String: String]

  public init(_ document: String) throws {
    var values: [String: String] = [:]
    for (offset, sourceLine) in document.split(separator: "\n", omittingEmptySubsequences: false)
      .enumerated()
    {
      let line = sourceLine.trimmingCharacters(in: .whitespaces)
      guard !line.isEmpty, !line.hasPrefix("#") else { continue }
      guard let separator = line.firstIndex(of: "=") else {
        throw ParseError.invalidLine(offset + 1)
      }
      let key = line[..<separator].trimmingCharacters(in: .whitespaces)
      let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
      guard !key.isEmpty, !value.isEmpty else { throw ParseError.invalidLine(offset + 1) }
      values[key] = value
    }
    self.values = values
  }

  public func bool(_ key: String) throws -> Bool? {
    guard let value = values[key] else { return nil }
    switch value {
    case "true": return true
    case "false": return false
    default: throw ParseError.invalidValue(key)
    }
  }

  public func double(_ key: String) throws -> Double? {
    guard let value = values[key] else { return nil }
    guard let number = Double(value), number.isFinite else { throw ParseError.invalidValue(key) }
    return number
  }

  public func string(_ key: String) throws -> String? {
    guard let value = values[key] else { return nil }
    do {
      return try JSONDecoder().decode(String.self, from: Data(value.utf8))
    } catch {
      throw ParseError.invalidValue(key)
    }
  }

  public static func quoted(_ value: String) throws -> String {
    String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
  }

  public static func document(header: [String], fields: [(String, String)]) -> String {
    header.map { "# \($0)" }.joined(separator: "\n")
      + "\n\n"
      + fields.map { "\($0) = \($1)" }.joined(separator: "\n")
      + "\n"
  }

  public enum ParseError: LocalizedError {
    case invalidLine(Int)
    case invalidValue(String)

    public var errorDescription: String? {
      switch self {
      case .invalidLine(let line): "Invalid TOML on line \(line)"
      case .invalidValue(let key): "Invalid TOML value for \(key)"
      }
    }
  }
}
