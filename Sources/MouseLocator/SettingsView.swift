import MouseLocatorCore
import SwiftUI

@MainActor
final class LocatorSettings: NSObject, ObservableObject {
  static let shared = LocatorSettings()
  private static let changedNotification = Notification.Name("dev.brice.MouseLocator.settingsChanged")

  @Published var sonarDelay: Double { didSet { save() } }
  @Published var sonarEnabled: Bool { didSet { save() } }
  @Published var sonarSize: Double { didSet { save() } }
  @Published var sonarThickness: Double { didSet { save() } }
  @Published var tailEnabled: Bool { didSet { save() } }
  @Published var tailThickness: Double { didSet { save() } }
  @Published private(set) var storageError: String?

  let configurationURL: URL

  private var isReady = false
  private let notificationSender = String(ProcessInfo.processInfo.processIdentifier)

  override private init() {
    let fileManager = FileManager.default
    configurationURL = ConfigurationLocation.settingsURL(
      xdgConfigHome: ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"],
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

    sonarDelay = stored.sonarDelay
    sonarEnabled = stored.sonarEnabled
    sonarSize = stored.sonarSize
    sonarThickness = stored.sonarThickness
    tailEnabled = stored.tailEnabled
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
          sonarDelay: sonarDelay,
          sonarEnabled: sonarEnabled,
          sonarSize: sonarSize,
          sonarThickness: sonarThickness,
          tailEnabled: tailEnabled,
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
      sonarDelay = stored.sonarDelay
      sonarEnabled = stored.sonarEnabled
      sonarSize = stored.sonarSize
      sonarThickness = stored.sonarThickness
      tailEnabled = stored.tailEnabled
      tailThickness = stored.tailThickness
      isReady = true
      storageError = nil
    } catch {
      storageError = "Could not reload settings: \(error.localizedDescription)"
    }
  }
}

private struct StoredSettings: Codable {
  var sonarDelay = 3.0
  var sonarEnabled = true
  var sonarSize = 180.0
  var sonarThickness = 8.0
  var tailEnabled = true
  var tailThickness = 8.0

  init() {}

  init(
    sonarDelay: Double,
    sonarEnabled: Bool,
    sonarSize: Double,
    sonarThickness: Double,
    tailEnabled: Bool,
    tailThickness: Double
  ) {
    self.sonarDelay = sonarDelay
    self.sonarEnabled = sonarEnabled
    self.sonarSize = sonarSize
    self.sonarThickness = sonarThickness
    self.tailEnabled = tailEnabled
    self.tailThickness = tailThickness
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
      }

      Section("Idle Sonar") {
        Toggle("Pulse when the pointer moves after being idle", isOn: $settings.sonarEnabled)

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
    .frame(width: 460, height: 480)
  }
}
