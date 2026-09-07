import AppKit
import MouseLocatorCore
import SwiftUI

@MainActor
final class LocatorSettings: NSObject, ObservableObject {
  static let shared = LocatorSettings()
  private static let changedNotification = Notification.Name(
    "dev.brice.MouseLocator.settingsChanged")

  @Published var menuBarIconEnabled: Bool { didSet { save() } }
  @Published var sonarDelay: Double { didSet { save() } }
  @Published var sonarEnabled: Bool { didSet { save() } }
  @Published var sonarColor: String { didSet { save() } }
  @Published var sonarRainbow: Bool { didSet { save() } }
  @Published var sonarSize: Double { didSet { save() } }
  @Published var sonarThickness: Double { didSet { save() } }
  @Published var tailColor: String { didSet { save() } }
  @Published var tailDotsEnabled: Bool { didSet { save() } }
  @Published var tailEnabled: Bool { didSet { save() } }
  @Published var tailGap: Double { didSet { save() } }
  @Published var tailRainbow: Bool { didSet { save() } }
  @Published var tailSmoothing: String { didSet { save() } }
  @Published var tailThickness: Double { didSet { save() } }
  @Published private(set) var storageError: String?

  let configurationURL: URL

  private var isReady = false
  private let notificationSender = String(ProcessInfo.processInfo.processIdentifier)

  override private init() {
    let fileManager = FileManager.default
    let commandLineConfigHome = CommandLine.arguments
      .first { $0.hasPrefix("--config-home=") }
      .map { String($0.dropFirst("--config-home=".count)) }
    configurationURL = ConfigurationLocation.settingsURL(
      xdgConfigHome: commandLineConfigHome
        ?? ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"],
      homeDirectory: fileManager.homeDirectoryForCurrentUser
    )

    var shouldSave = false
    let stored: StoredSettings
    if fileManager.fileExists(atPath: configurationURL.path) {
      do {
        stored = try JSONDecoder().decode(
          StoredSettings.self,
          from: Data(contentsOf: configurationURL)
        )
        shouldSave = stored.needsUpgrade
      } catch {
        stored = StoredSettings()
        storageError = "Could not read settings: \(error.localizedDescription)"
      }
    } else {
      stored = StoredSettings(
        legacy: UserDefaults.standard.persistentDomain(forName: "dev.brice.MouseLocator") ?? [:]
      )
      shouldSave = true
    }

    menuBarIconEnabled = stored.menuBarIconEnabled ?? true
    sonarDelay = stored.sonarDelay
    sonarEnabled = stored.sonarEnabled
    sonarColor = stored.sonarColor ?? "accent"
    sonarRainbow = stored.sonarRainbow ?? false
    sonarSize = stored.sonarSize
    sonarThickness = stored.sonarThickness
    tailColor = stored.tailColor ?? "accent"
    tailDotsEnabled = stored.tailDotsEnabled ?? false
    tailEnabled = stored.tailEnabled
    tailGap = stored.tailGap ?? 16
    tailRainbow = stored.tailRainbow ?? false
    tailSmoothing = stored.tailSmoothing ?? "bezier"
    tailThickness = stored.tailThickness
    super.init()
    isReady = true
    if shouldSave { save() }
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(reloadSettings(_:)),
      name: Self.changedNotification,
      object: nil
    )
  }

  private func save() {
    guard isReady else { return }
    do {
      try FileManager.default.createDirectory(
        at: configurationURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(
        StoredSettings(
          menuBarIconEnabled: menuBarIconEnabled,
          sonarDelay: sonarDelay,
          sonarEnabled: sonarEnabled,
          sonarColor: sonarColor,
          sonarRainbow: sonarRainbow,
          sonarSize: sonarSize,
          sonarThickness: sonarThickness,
          tailColor: tailColor,
          tailDotsEnabled: tailDotsEnabled,
          tailEnabled: tailEnabled,
          tailGap: tailGap,
          tailRainbow: tailRainbow,
          tailSmoothing: tailSmoothing,
          tailThickness: tailThickness
        )
      ).write(to: configurationURL, options: .atomic)
      storageError = nil
      DistributedNotificationCenter.default().postNotificationName(
        Self.changedNotification,
        object: notificationSender,
        userInfo: nil,
        deliverImmediately: true
      )
    } catch {
      storageError = "Could not save settings: \(error.localizedDescription)"
    }
  }

  @objc private func reloadSettings(_ notification: Notification) {
    guard notification.object as? String != notificationSender else { return }
    do {
      let stored = try JSONDecoder().decode(
        StoredSettings.self,
        from: Data(contentsOf: configurationURL)
      )
      isReady = false
      menuBarIconEnabled = stored.menuBarIconEnabled ?? true
      sonarDelay = stored.sonarDelay
      sonarEnabled = stored.sonarEnabled
      sonarColor = stored.sonarColor ?? "accent"
      sonarRainbow = stored.sonarRainbow ?? false
      sonarSize = stored.sonarSize
      sonarThickness = stored.sonarThickness
      tailColor = stored.tailColor ?? "accent"
      tailDotsEnabled = stored.tailDotsEnabled ?? false
      tailEnabled = stored.tailEnabled
      tailGap = stored.tailGap ?? 16
      tailRainbow = stored.tailRainbow ?? false
      tailSmoothing = stored.tailSmoothing ?? "bezier"
      tailThickness = stored.tailThickness
      isReady = true
      storageError = nil
    } catch {
      storageError = "Could not reload settings: \(error.localizedDescription)"
    }
  }
}

private struct StoredSettings: Codable {
  var menuBarIconEnabled: Bool?
  var sonarDelay = 3.0
  var sonarEnabled = true
  var sonarColor: String?
  var sonarRainbow: Bool?
  var sonarSize = 180.0
  var sonarThickness = 3.0
  var tailColor: String?
  var tailDotsEnabled: Bool?
  var tailEnabled = true
  var tailGap: Double?
  var tailRainbow: Bool?
  var tailSmoothing: String?
  var tailThickness = 3.0

  init() {}

  init(
    menuBarIconEnabled: Bool,
    sonarDelay: Double,
    sonarEnabled: Bool,
    sonarColor: String,
    sonarRainbow: Bool,
    sonarSize: Double,
    sonarThickness: Double,
    tailColor: String,
    tailDotsEnabled: Bool,
    tailEnabled: Bool,
    tailGap: Double,
    tailRainbow: Bool,
    tailSmoothing: String,
    tailThickness: Double
  ) {
    self.menuBarIconEnabled = menuBarIconEnabled
    self.sonarDelay = sonarDelay
    self.sonarEnabled = sonarEnabled
    self.sonarColor = sonarColor
    self.sonarRainbow = sonarRainbow
    self.sonarSize = sonarSize
    self.sonarThickness = sonarThickness
    self.tailColor = tailColor
    self.tailDotsEnabled = tailDotsEnabled
    self.tailEnabled = tailEnabled
    self.tailGap = tailGap
    self.tailRainbow = tailRainbow
    self.tailSmoothing = tailSmoothing
    self.tailThickness = tailThickness
  }

  var needsUpgrade: Bool {
    menuBarIconEnabled == nil || sonarColor == nil || sonarRainbow == nil || tailColor == nil
      || tailDotsEnabled == nil
      || tailGap == nil || tailRainbow == nil || tailSmoothing == nil
  }

  init(legacy: [String: Any]) {
    sonarDelay = (legacy["sonarDelay"] as? NSNumber)?.doubleValue ?? sonarDelay
    sonarEnabled = (legacy["sonarEnabled"] as? NSNumber)?.boolValue ?? sonarEnabled
    sonarSize = (legacy["sonarSize"] as? NSNumber)?.doubleValue ?? sonarSize
    sonarThickness = (legacy["sonarThickness"] as? NSNumber)?.doubleValue ?? sonarThickness
    tailEnabled = (legacy["tailEnabled"] as? NSNumber)?.boolValue ?? tailEnabled
    tailThickness = (legacy["tailSize"] as? NSNumber)?.doubleValue ?? tailThickness
  }
}

struct SettingsView: View {
  @ObservedObject var settings: LocatorSettings

  var body: some View {
    Form {
      Section("Mouse Tail") {
        Toggle("Show a fading trail behind the pointer", isOn: $settings.tailEnabled)

        ColorPicker("Trail color", selection: tailColor, supportsOpacity: false)
          .disabled(!settings.tailEnabled || settings.tailRainbow)

        Toggle("Rainbow colors", isOn: $settings.tailRainbow)
          .disabled(!settings.tailEnabled)

        LabeledContent("Trail thickness") {
          HStack {
            Slider(value: $settings.tailThickness, in: 2...20, step: 1)
              .frame(width: 180)
            Text("\(Int(settings.tailThickness)) pt")
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!settings.tailEnabled)

        LabeledContent("Cursor gap") {
          HStack {
            Slider(value: $settings.tailGap, in: 0...80, step: 2)
              .frame(width: 180)
            Text("\(Int(settings.tailGap)) pt")
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!settings.tailEnabled)
      }

      Section("Idle Pulse") {
        Toggle("Pulse when the pointer moves after being idle", isOn: $settings.sonarEnabled)

        ColorPicker("Circle color", selection: sonarColor, supportsOpacity: false)
          .disabled(!settings.sonarEnabled || settings.sonarRainbow)

        Toggle("Rainbow colors", isOn: $settings.sonarRainbow)
          .disabled(!settings.sonarEnabled)

        LabeledContent("Inactivity delay") {
          HStack {
            Slider(value: $settings.sonarDelay, in: 1...15, step: 0.5)
              .frame(width: 180)
            Text("\(settings.sonarDelay, specifier: "%.1f") s")
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!settings.sonarEnabled)

        LabeledContent("Circle thickness") {
          HStack {
            Slider(value: $settings.sonarThickness, in: 2...20, step: 1)
              .frame(width: 180)
            Text("\(Int(settings.sonarThickness)) pt")
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!settings.sonarEnabled)

        LabeledContent("Maximum size") {
          HStack {
            Slider(value: $settings.sonarSize, in: 80...300, step: 10)
              .frame(width: 180)
            Text("\(Int(settings.sonarSize)) pt")
              .monospacedDigit()
              .frame(width: 52, alignment: .trailing)
          }
        }
        .disabled(!settings.sonarEnabled)
      }

      Section("Menu Bar") {
        Toggle("Show Mouse Locator in the menu bar", isOn: $settings.menuBarIconEnabled)
      }

      Section("Storage") {
        Text(settings.configurationURL.path(percentEncoded: false))
          .font(.caption)
          .textSelection(.enabled)
        if let storageError = settings.storageError {
          Text(storageError)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
    }
    .formStyle(.grouped)
  }

  private var tailColor: Binding<Color> {
    Binding(
      get: { Color(nsColor: .locatorColor(settings.tailColor)) },
      set: { settings.tailColor = NSColor($0).locatorHexRGB }
    )
  }

  private var sonarColor: Binding<Color> {
    Binding(
      get: { Color(nsColor: .locatorColor(settings.sonarColor)) },
      set: { settings.sonarColor = NSColor($0).locatorHexRGB }
    )
  }
}

extension NSColor {
  static func locatorColor(_ value: String) -> NSColor {
    guard value.count == 7,
      value.first == "#",
      let rgb = UInt32(value.dropFirst(), radix: 16)
    else {
      return .controlAccentColor
    }

    return NSColor(
      srgbRed: CGFloat((rgb >> 16) & 0xff) / 255,
      green: CGFloat((rgb >> 8) & 0xff) / 255,
      blue: CGFloat(rgb & 0xff) / 255,
      alpha: 1
    )
  }

  var locatorHexRGB: String {
    let color = usingColorSpace(.sRGB) ?? self
    return String(
      format: "#%02X%02X%02X",
      Int((color.redComponent * 255).rounded()),
      Int((color.greenComponent * 255).rounded()),
      Int((color.blueComponent * 255).rounded())
    )
  }
}
