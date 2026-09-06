import SwiftUI

enum LocatorDefaults {
  static let tailEnabled = "tailEnabled"
  static let tailSize = "tailSize"

  static func register() {
    UserDefaults.standard.register(defaults: [
      tailEnabled: true,
      tailSize: 8.0,
    ])
  }
}

struct SettingsView: View {
  @AppStorage(LocatorDefaults.tailEnabled) private var tailEnabled = true
  @AppStorage(LocatorDefaults.tailSize) private var tailSize = 8.0

  var body: some View {
    Form {
      Section("Mouse Tail") {
        Toggle("Show a fading trail behind the pointer", isOn: $tailEnabled)

        LabeledContent("Trail size") {
          HStack {
            Slider(value: $tailSize, in: 2...20, step: 1)
              .frame(width: 180)
            Text("\(Int(tailSize)) pt")
              .monospacedDigit()
              .frame(width: 44, alignment: .trailing)
          }
        }
        .disabled(!tailEnabled)
      }
    }
    .formStyle(.grouped)
    .frame(width: 460, height: 190)
  }
}

