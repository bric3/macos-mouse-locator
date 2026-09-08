// Copyright 2026 Brice Dutheil
// SPDX-License-Identifier: MPL-2.0

import AppKit
import MouseLocatorCore
import SwiftUI

private final class LocalizationToken: NSObject {}

enum L10n {
  private static let bundle = Bundle(for: LocalizationToken.self)

  static func text(_ key: String) -> String {
    bundle.localizedString(forKey: key, value: key, table: nil)
  }

  static func format(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: text(key), locale: .current, arguments: arguments)
  }
}

@MainActor
final class LocatorSettings: NSObject, ObservableObject {
  static let shared = LocatorSettings()
  static let inputMonitoringStatusRequest = Notification.Name(
    "dev.brice.MouseLocator.inputMonitoringStatusRequest")
  private static let changedNotification = Notification.Name(
    "dev.brice.MouseLocator.settingsChanged")
  private static let inputMonitoringStatusNotification = Notification.Name(
    "dev.brice.MouseLocator.inputMonitoringStatusChanged")

  @Published var menuBarIconEnabled: Bool { didSet { saveNow() } }
  @Published var modifierPulseEnabled: Bool { didSet { saveNow() } }
  @Published var modifierPulseKey: String { didSet { saveNow() } }
  @Published var modifierTapDuration: Double { didSet { saveNow() } }
  @Published var sonarDelay: Double { didSet { scheduleSave() } }
  @Published var sonarEnabled: Bool { didSet { saveNow() } }
  @Published var sonarColor: String { didSet { scheduleSave() } }
  @Published var sonarExpansionSpeed: Double { didSet { scheduleSave() } }
  @Published var sonarRainbow: Bool { didSet { saveNow() } }
  @Published var sonarSize: Double { didSet { scheduleSave() } }
  @Published var sonarThickness: Double { didSet { scheduleSave() } }
  @Published var tailColor: String { didSet { scheduleSave() } }
  @Published var tailActivationMode: String { didSet { saveNow() } }
  @Published var tailDotsEnabled: Bool { didSet { saveNow() } }
  @Published var tailEnabled: Bool { didSet { saveNow() } }
  @Published var tailGap: Double { didSet { scheduleSave() } }
  @Published var tailInactivityDelay: Double { didSet { scheduleSave() } }
  @Published var tailRainbow: Bool { didSet { saveNow() } }
  @Published var tailSpeedShadingEnabled: Bool { didSet { saveNow() } }
  @Published var tailSmoothing: String { didSet { saveNow() } }
  @Published var tailThickness: Double { didSet { scheduleSave() } }
  @Published private(set) var inputMonitoringPermissionGranted: Bool?
  @Published private(set) var storageError: String?

  let configurationURL: URL

  private var isReady = false
  private var pendingSave: Task<Void, Never>?
  private let notificationSender = String(ProcessInfo.processInfo.processIdentifier)

  override private init() {
    let fileManager = FileManager.default
    let commandLineConfigHome = CommandLine.arguments
      .first { $0.hasPrefix("--config-home=") }
      .map { String($0.dropFirst("--config-home=".count)) }
    let configHome = commandLineConfigHome
      ?? ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
    configurationURL = ConfigurationLocation.settingsURL(
      xdgConfigHome: configHome,
      homeDirectory: fileManager.homeDirectoryForCurrentUser
    )
    let legacyConfigurationURL = ConfigurationLocation.legacySettingsURL(
      xdgConfigHome: configHome,
      homeDirectory: fileManager.homeDirectoryForCurrentUser
    )

    var shouldSave = false
    let stored: StoredSettings
    if fileManager.fileExists(atPath: configurationURL.path) {
      do {
        stored = try StoredSettings(
          toml: String(contentsOf: configurationURL, encoding: .utf8)
        )
        shouldSave = stored.needsUpgrade
      } catch {
        stored = StoredSettings()
        storageError = L10n.format("Could not read settings: %@", error.localizedDescription)
      }
    } else if fileManager.fileExists(atPath: legacyConfigurationURL.path) {
      do {
        stored = try JSONDecoder().decode(
          StoredSettings.self,
          from: Data(contentsOf: legacyConfigurationURL)
        )
        shouldSave = true
      } catch {
        stored = StoredSettings()
        storageError = L10n.format("Could not read settings: %@", error.localizedDescription)
      }
    } else {
      stored = StoredSettings(
        legacy: UserDefaults.standard.persistentDomain(forName: "dev.brice.MouseLocator") ?? [:]
      )
      shouldSave = true
    }

    menuBarIconEnabled = stored.menuBarIconEnabled ?? true
    modifierPulseEnabled = stored.modifierPulseEnabled ?? false
    modifierPulseKey = stored.resolvedModifierPulseKey
    modifierTapDuration = stored.modifierTapDuration ?? 0.35
    sonarDelay = stored.sonarDelay
    sonarEnabled = stored.sonarEnabled
    sonarColor = stored.sonarColor ?? "accent"
    sonarExpansionSpeed = stored.sonarExpansionSpeed ?? 1
    sonarRainbow = stored.sonarRainbow ?? false
    sonarSize = stored.sonarSize
    sonarThickness = stored.sonarThickness
    tailColor = stored.tailColor ?? "accent"
    tailActivationMode = stored.tailActivationMode == "afterInactivity"
      ? "afterInactivity" : "always"
    tailDotsEnabled = stored.tailDotsEnabled ?? false
    tailEnabled = stored.tailEnabled
    tailGap = stored.tailGap ?? 16
    tailInactivityDelay = stored.tailInactivityDelay ?? 3
    tailRainbow = stored.tailRainbow ?? false
    tailSpeedShadingEnabled = stored.tailSpeedShadingEnabled ?? true
    tailSmoothing = stored.tailSmoothing ?? "bezier"
    tailThickness = stored.tailThickness
    super.init()
    isReady = true
    if shouldSave { saveNow() }
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(reloadSettings(_:)),
      name: Self.changedNotification,
      object: nil
    )
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(inputMonitoringStatusChanged(_:)),
      name: Self.inputMonitoringStatusNotification,
      object: nil
    )
  }

  func requestInputMonitoringStatus() {
    DistributedNotificationCenter.default().postNotificationName(
      Self.inputMonitoringStatusRequest,
      object: notificationSender,
      userInfo: nil,
      deliverImmediately: true
    )
  }

  func publishInputMonitoringStatus(_ granted: Bool) {
    inputMonitoringPermissionGranted = granted
    DistributedNotificationCenter.default().postNotificationName(
      Self.inputMonitoringStatusNotification,
      object: notificationSender,
      userInfo: ["granted": NSNumber(value: granted)],
      deliverImmediately: true
    )
  }

  private func scheduleSave() {
    guard isReady else { return }
    pendingSave?.cancel()
    pendingSave = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(150))
      guard !Task.isCancelled else { return }
      self?.saveNow()
    }
  }

  func flush() {
    guard pendingSave != nil else { return }
    saveNow()
  }

  private func saveNow() {
    pendingSave?.cancel()
    pendingSave = nil
    guard isReady else { return }
    do {
      try FileManager.default.createDirectory(
        at: configurationURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try StoredSettings(
        menuBarIconEnabled: menuBarIconEnabled,
        modifierPulseEnabled: modifierPulseEnabled,
        modifierPulseKey: modifierPulseKey,
        modifierTapDuration: modifierTapDuration,
        sonarDelay: sonarDelay,
        sonarEnabled: sonarEnabled,
        sonarColor: sonarColor,
        sonarExpansionSpeed: sonarExpansionSpeed,
        sonarRainbow: sonarRainbow,
        sonarSize: sonarSize,
        sonarThickness: sonarThickness,
        tailColor: tailColor,
        tailActivationMode: tailActivationMode,
        tailDotsEnabled: tailDotsEnabled,
        tailEnabled: tailEnabled,
        tailGap: tailGap,
        tailInactivityDelay: tailInactivityDelay,
        tailRainbow: tailRainbow,
        tailSpeedShadingEnabled: tailSpeedShadingEnabled,
        tailSmoothing: tailSmoothing,
        tailThickness: tailThickness
      ).toml.write(to: configurationURL, atomically: true, encoding: .utf8)
      storageError = nil
      DistributedNotificationCenter.default().postNotificationName(
        Self.changedNotification,
        object: notificationSender,
        userInfo: nil,
        deliverImmediately: true
      )
    } catch {
      storageError = L10n.format("Could not save settings: %@", error.localizedDescription)
    }
  }

  @objc private func reloadSettings(_ notification: Notification) {
    guard notification.object as? String != notificationSender else { return }
    pendingSave?.cancel()
    pendingSave = nil
    do {
      let stored = try StoredSettings(
        toml: String(contentsOf: configurationURL, encoding: .utf8)
      )
      isReady = false
      menuBarIconEnabled = stored.menuBarIconEnabled ?? true
      modifierPulseEnabled = stored.modifierPulseEnabled ?? false
      modifierPulseKey = stored.resolvedModifierPulseKey
      modifierTapDuration = stored.modifierTapDuration ?? 0.35
      sonarDelay = stored.sonarDelay
      sonarEnabled = stored.sonarEnabled
      sonarColor = stored.sonarColor ?? "accent"
      sonarExpansionSpeed = stored.sonarExpansionSpeed ?? 1
      sonarRainbow = stored.sonarRainbow ?? false
      sonarSize = stored.sonarSize
      sonarThickness = stored.sonarThickness
      tailColor = stored.tailColor ?? "accent"
      tailActivationMode = stored.tailActivationMode == "afterInactivity"
        ? "afterInactivity" : "always"
      tailDotsEnabled = stored.tailDotsEnabled ?? false
      tailEnabled = stored.tailEnabled
      tailGap = stored.tailGap ?? 16
      tailInactivityDelay = stored.tailInactivityDelay ?? 3
      tailRainbow = stored.tailRainbow ?? false
      tailSpeedShadingEnabled = stored.tailSpeedShadingEnabled ?? true
      tailSmoothing = stored.tailSmoothing ?? "bezier"
      tailThickness = stored.tailThickness
      isReady = true
      storageError = nil
    } catch {
      storageError = L10n.format("Could not reload settings: %@", error.localizedDescription)
    }
  }

  @objc private func inputMonitoringStatusChanged(_ notification: Notification) {
    guard let granted = notification.userInfo?["granted"] as? NSNumber else { return }
    inputMonitoringPermissionGranted = granted.boolValue
  }
}

private struct StoredSettings: Codable {
  var menuBarIconEnabled: Bool?
  var modifierPulseEnabled: Bool?
  var modifierPulseKey: String?
  var modifierTapDuration: Double?
  var sonarDelay = 3.0
  var sonarEnabled = true
  var sonarColor: String?
  var sonarExpansionSpeed: Double?
  var sonarRainbow: Bool?
  var sonarSize = 180.0
  var sonarThickness = 3.0
  var tailColor: String?
  var tailActivationMode: String?
  var tailDotsEnabled: Bool?
  var tailEnabled = true
  var tailGap: Double?
  var tailInactivityDelay: Double?
  var tailRainbow: Bool?
  var tailSpeedShadingEnabled: Bool?
  var tailSmoothing: String?
  var tailThickness = 3.0

  init() {}

  init(
    menuBarIconEnabled: Bool,
    modifierPulseEnabled: Bool,
    modifierPulseKey: String,
    modifierTapDuration: Double,
    sonarDelay: Double,
    sonarEnabled: Bool,
    sonarColor: String,
    sonarExpansionSpeed: Double,
    sonarRainbow: Bool,
    sonarSize: Double,
    sonarThickness: Double,
    tailColor: String,
    tailActivationMode: String,
    tailDotsEnabled: Bool,
    tailEnabled: Bool,
    tailGap: Double,
    tailInactivityDelay: Double,
    tailRainbow: Bool,
    tailSpeedShadingEnabled: Bool,
    tailSmoothing: String,
    tailThickness: Double
  ) {
    self.menuBarIconEnabled = menuBarIconEnabled
    self.modifierPulseEnabled = modifierPulseEnabled
    self.modifierPulseKey = modifierPulseKey
    self.modifierTapDuration = modifierTapDuration
    self.sonarDelay = sonarDelay
    self.sonarEnabled = sonarEnabled
    self.sonarColor = sonarColor
    self.sonarExpansionSpeed = sonarExpansionSpeed
    self.sonarRainbow = sonarRainbow
    self.sonarSize = sonarSize
    self.sonarThickness = sonarThickness
    self.tailColor = tailColor
    self.tailActivationMode = tailActivationMode
    self.tailDotsEnabled = tailDotsEnabled
    self.tailEnabled = tailEnabled
    self.tailGap = tailGap
    self.tailInactivityDelay = tailInactivityDelay
    self.tailRainbow = tailRainbow
    self.tailSpeedShadingEnabled = tailSpeedShadingEnabled
    self.tailSmoothing = tailSmoothing
    self.tailThickness = tailThickness
  }

  var needsUpgrade: Bool {
    menuBarIconEnabled == nil || modifierPulseEnabled == nil || modifierPulseKey == nil
      || modifierTapDuration == nil || sonarColor == nil || sonarExpansionSpeed == nil
      || sonarRainbow == nil || tailColor == nil || tailActivationMode == nil
      || tailDotsEnabled == nil || tailGap == nil || tailInactivityDelay == nil
      || tailRainbow == nil || tailSpeedShadingEnabled == nil || tailSmoothing == nil
  }

  var resolvedModifierPulseKey: String {
    switch modifierPulseKey {
    case "option": "option"
    case "command": "command"
    default: "control"
    }
  }

  init(legacy: [String: Any]) {
    sonarDelay = (legacy["sonarDelay"] as? NSNumber)?.doubleValue ?? sonarDelay
    sonarEnabled = (legacy["sonarEnabled"] as? NSNumber)?.boolValue ?? sonarEnabled
    sonarSize = (legacy["sonarSize"] as? NSNumber)?.doubleValue ?? sonarSize
    sonarThickness = (legacy["sonarThickness"] as? NSNumber)?.doubleValue ?? sonarThickness
    tailEnabled = (legacy["tailEnabled"] as? NSNumber)?.boolValue ?? tailEnabled
    tailThickness = (legacy["tailSize"] as? NSNumber)?.doubleValue ?? tailThickness
  }

  init(toml source: String) throws {
    let toml = try FlatTOML(source)
    menuBarIconEnabled = try toml.bool("menuBarIconEnabled")
    modifierPulseEnabled = try toml.bool("modifierPulseEnabled")
    modifierPulseKey = try toml.string("modifierPulseKey")
    modifierTapDuration = try toml.double("modifierTapDuration")
    sonarDelay = try toml.double("sonarDelay") ?? sonarDelay
    sonarEnabled = try toml.bool("sonarEnabled") ?? sonarEnabled
    sonarColor = try toml.string("sonarColor")
    sonarExpansionSpeed = try toml.double("sonarExpansionSpeed")
    sonarRainbow = try toml.bool("sonarRainbow")
    sonarSize = try toml.double("sonarSize") ?? sonarSize
    sonarThickness = try toml.double("sonarThickness") ?? sonarThickness
    tailColor = try toml.string("tailColor")
    tailActivationMode = try toml.string("tailActivationMode")
    tailDotsEnabled = try toml.bool("tailDotsEnabled")
    tailEnabled = try toml.bool("tailEnabled") ?? tailEnabled
    tailGap = try toml.double("tailGap")
    tailInactivityDelay = try toml.double("tailInactivityDelay")
    tailRainbow = try toml.bool("tailRainbow")
    tailSpeedShadingEnabled = try toml.bool("tailSpeedShadingEnabled")
    tailSmoothing = try toml.string("tailSmoothing")
    tailThickness = try toml.double("tailThickness") ?? tailThickness
  }

  var toml: String {
    get throws {
      try FlatTOML.document(
        header: [
          "Mouse Locator settings",
          "Key names are not stable yet and may change before the first stable release.",
          "modifierTapDuration is the maximum modifier-only tap length in seconds.",
        ],
        fields: [
          ("menuBarIconEnabled", String(menuBarIconEnabled ?? true)),
          ("modifierPulseEnabled", String(modifierPulseEnabled ?? false)),
          ("modifierPulseKey", FlatTOML.quoted(modifierPulseKey ?? "control")),
          ("modifierTapDuration", String(modifierTapDuration ?? 0.35)),
          ("tailEnabled", String(tailEnabled)),
          ("tailActivationMode", FlatTOML.quoted(tailActivationMode ?? "always")),
          ("tailInactivityDelay", String(tailInactivityDelay ?? 3)),
          ("tailColor", FlatTOML.quoted(tailColor ?? "accent")),
          ("tailRainbow", String(tailRainbow ?? false)),
          ("tailSpeedShadingEnabled", String(tailSpeedShadingEnabled ?? true)),
          ("tailThickness", String(tailThickness)),
          ("tailGap", String(tailGap ?? 16)),
          ("tailDotsEnabled", String(tailDotsEnabled ?? false)),
          ("tailSmoothing", FlatTOML.quoted(tailSmoothing ?? "bezier")),
          ("sonarEnabled", String(sonarEnabled)),
          ("sonarDelay", String(sonarDelay)),
          ("sonarColor", FlatTOML.quoted(sonarColor ?? "accent")),
          ("sonarRainbow", String(sonarRainbow ?? false)),
          ("sonarExpansionSpeed", String(sonarExpansionSpeed ?? 1)),
          ("sonarThickness", String(sonarThickness)),
          ("sonarSize", String(sonarSize)),
        ]
      )
    }
  }
}

struct SettingsView: View {
  @ObservedObject var settings: LocatorSettings
  @State private var showingInputMonitoringHelp = false

  var body: some View {
    Form {
      Section(L10n.text("Menu Bar")) {
        Toggle(L10n.text("Show Mouse Locator in the menu bar"), isOn: $settings.menuBarIconEnabled)
      }

      Section(L10n.text("Mouse Tail")) {
        Toggle(L10n.text("Show a fading trail behind the pointer"), isOn: $settings.tailEnabled)

        Picker(L10n.text("Show trail"), selection: $settings.tailActivationMode) {
          Text(L10n.text("Always")).tag("always")
          Text(L10n.text("After inactivity")).tag("afterInactivity")
        }
        .disabled(!settings.tailEnabled)

        LabeledContent(L10n.text("Inactivity delay")) {
          HStack {
            Slider(value: $settings.tailInactivityDelay, in: 1...15, step: 0.5)
              .frame(width: 180)
            Text(L10n.format("%.1f s", settings.tailInactivityDelay))
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!settings.tailEnabled || settings.tailActivationMode != "afterInactivity")

        LabeledContent(L10n.text("Color")) {
          HStack(spacing: 8) {
            Toggle(L10n.text("Rainbow colors"), isOn: $settings.tailRainbow)
              .fixedSize()
            Divider()
              .frame(height: 18)
            ColorPicker(
              L10n.text("Trail color"), selection: tailColor, supportsOpacity: false
            )
            .labelsHidden()
            .disabled(settings.tailRainbow)
          }
        }
        .disabled(!settings.tailEnabled)

        Toggle(
          L10n.text("Speed-sensitive shading"),
          isOn: $settings.tailSpeedShadingEnabled
        )
        .disabled(!settings.tailEnabled)

        LabeledContent(L10n.text("Trail thickness")) {
          HStack {
            Slider(value: $settings.tailThickness, in: 2...20, step: 1)
              .frame(width: 180)
            Text(L10n.format("%d pt", Int(settings.tailThickness)))
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!settings.tailEnabled)

        LabeledContent(L10n.text("Cursor gap")) {
          HStack {
            Slider(value: $settings.tailGap, in: 0...80, step: 2)
              .frame(width: 180)
            Text(L10n.format("%d pt", Int(settings.tailGap)))
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!settings.tailEnabled)
      }

      Section(L10n.text("Idle Pulse")) {
        Toggle(
          L10n.text("Pulse when the pointer moves after being idle"),
          isOn: $settings.sonarEnabled
        )

        LabeledContent {
          Toggle(
            L10n.text("Pulse on modifier key"),
            isOn: $settings.modifierPulseEnabled
          )
          .labelsHidden()
        } label: {
          HStack(spacing: 6) {
            Text(L10n.text("Pulse on modifier key"))
            Button {
              showingInputMonitoringHelp.toggle()
            } label: {
              Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            .help(L10n.text("About modifier-key permission"))
            .popover(isPresented: $showingInputMonitoringHelp) {
              VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("Modifier-key permission"))
                  .font(.headline)
                Text(
                  L10n.text(
                    "Input Monitoring is required only for detecting modifier keys outside Mouse Locator."
                  )
                )
                Text(
                  L10n.text(
                    "Open Input Monitoring Settings, add Mouse Locator with the + button if needed, then turn it on."
                  )
                )
                Text(
                  L10n.text(
                    "Return to this pane; the status should change to granted automatically."
                  )
                )
                Text(
                  L10n.text("Accessibility is not required by this version and can be disabled.")
                )
                .foregroundStyle(.secondary)
              }
              .padding()
              .frame(width: 340)
            }
          }
        }

        Picker(L10n.text("Modifier key"), selection: $settings.modifierPulseKey) {
          Text(L10n.text("Control")).tag("control")
          Text(L10n.text("Option")).tag("option")
          Text(L10n.text("Command")).tag("command")
        }
        .disabled(!settings.modifierPulseEnabled)

        if settings.modifierPulseEnabled {
          HStack {
            if settings.inputMonitoringPermissionGranted == true {
              Label(L10n.text("Input Monitoring access granted"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            } else if settings.inputMonitoringPermissionGranted == false {
              Label(
                L10n.text("Input Monitoring access is required"),
                systemImage: "exclamationmark.triangle.fill"
              )
              .foregroundStyle(.secondary)
              Spacer()
              Button(L10n.text("Open Input Monitoring Settings")) {
                openInputMonitoringSettings()
              }
            } else {
              Label(L10n.text("Checking Input Monitoring access…"), systemImage: "hourglass")
                .foregroundStyle(.secondary)
            }
          }
          .font(.caption)
        }

        LabeledContent(L10n.text("Color")) {
          HStack(spacing: 8) {
            Toggle(L10n.text("Rainbow colors"), isOn: $settings.sonarRainbow)
              .fixedSize()
            Divider()
              .frame(height: 18)
            ColorPicker(
              L10n.text("Circle color"), selection: sonarColor, supportsOpacity: false
            )
            .labelsHidden()
            .disabled(settings.sonarRainbow)
          }
        }
        .disabled(!pulseEnabled)

        LabeledContent(L10n.text("Inactivity delay")) {
          HStack {
            Slider(value: $settings.sonarDelay, in: 1...15, step: 0.5)
              .frame(width: 180)
            Text(L10n.format("%.1f s", settings.sonarDelay))
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!settings.sonarEnabled)

        LabeledContent(L10n.text("Expansion speed")) {
          HStack {
            Slider(value: $settings.sonarExpansionSpeed, in: 0.5...3, step: 0.5)
              .frame(width: 180)
            Text(L10n.format("%.1f×", settings.sonarExpansionSpeed))
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!pulseEnabled)

        LabeledContent(L10n.text("Circle thickness")) {
          HStack {
            Slider(value: $settings.sonarThickness, in: 2...20, step: 1)
              .frame(width: 180)
            Text(L10n.format("%d pt", Int(settings.sonarThickness)))
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!pulseEnabled)

        LabeledContent(L10n.text("Maximum size")) {
          HStack {
            Slider(value: $settings.sonarSize, in: 80...300, step: 10)
              .frame(width: 180)
            Text(L10n.format("%d pt", Int(settings.sonarSize)))
              .monospacedDigit()
              .frame(width: 52, alignment: .trailing)
          }
        }
        .disabled(!pulseEnabled)
      }

      Section(L10n.text("Storage")) {
        HStack {
          Text(settings.configurationURL.path(percentEncoded: false))
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
          Spacer(minLength: 8)
          Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
              settings.configurationURL.path(percentEncoded: false),
              forType: .string
            )
          } label: {
            Label(L10n.text("Copy"), systemImage: "doc.on.doc")
          }
          .buttonStyle(.bordered)
        }
        if let storageError = settings.storageError {
          Text(storageError)
            .font(.caption)
            .foregroundStyle(.red)
        }
      }

    }
    .formStyle(.grouped)
    .onAppear { settings.requestInputMonitoringStatus() }
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

  private var pulseEnabled: Bool {
    settings.sonarEnabled || settings.modifierPulseEnabled
  }

  private func openInputMonitoringSettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    else { return }
    NSWorkspace.shared.open(url)
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
