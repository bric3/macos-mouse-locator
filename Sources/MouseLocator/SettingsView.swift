import SwiftUI

enum LocatorDefaults {
  static let sonarDelay = "sonarDelay"
  static let sonarEnabled = "sonarEnabled"
  static let sonarSize = "sonarSize"
  static let sonarThickness = "sonarThickness"
  static let tailEnabled = "tailEnabled"
  static let tailThickness = "tailSize"

  static func register() {
    UserDefaults.standard.register(defaults: [
      sonarDelay: 3.0,
      sonarEnabled: true,
      sonarSize: 180.0,
      sonarThickness: 8.0,
      tailEnabled: true,
      tailThickness: 8.0,
    ])
  }
}

struct SettingsView: View {
  @AppStorage(LocatorDefaults.sonarDelay) private var sonarDelay = 3.0
  @AppStorage(LocatorDefaults.sonarEnabled) private var sonarEnabled = true
  @AppStorage(LocatorDefaults.sonarSize) private var sonarSize = 180.0
  @AppStorage(LocatorDefaults.sonarThickness) private var sonarThickness = 8.0
  @AppStorage(LocatorDefaults.tailEnabled) private var tailEnabled = true
  @AppStorage(LocatorDefaults.tailThickness) private var tailThickness = 8.0

  var body: some View {
    Form {
      Section("Mouse Tail") {
        Toggle("Show a fading trail behind the pointer", isOn: $tailEnabled)

        LabeledContent("Trail thickness") {
          HStack {
            Slider(value: $tailThickness, in: 2...20, step: 1)
              .frame(width: 180)
            Text("\(Int(tailThickness)) pt")
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!tailEnabled)
      }

      Section("Idle Sonar") {
        Toggle("Pulse when the pointer moves after being idle", isOn: $sonarEnabled)

        LabeledContent("Inactivity delay") {
          HStack {
            Slider(value: $sonarDelay, in: 1...15, step: 0.5)
              .frame(width: 180)
            Text("\(sonarDelay, specifier: "%.1f") s")
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!sonarEnabled)

        LabeledContent("Circle thickness") {
          HStack {
            Slider(value: $sonarThickness, in: 2...20, step: 1)
              .frame(width: 180)
            Text("\(Int(sonarThickness)) pt")
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!sonarEnabled)

        LabeledContent("Maximum size") {
          HStack {
            Slider(value: $sonarSize, in: 80...300, step: 10)
              .frame(width: 180)
            Text("\(Int(sonarSize)) pt")
              .monospacedDigit()
              .frame(width: 52, alignment: .trailing)
          }
        }
        .disabled(!sonarEnabled)
      }
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 410)
  }
}
