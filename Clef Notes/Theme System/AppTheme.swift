import SwiftUI

// An enum to represent the available tint colors
enum AccentColor: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case red = "Red"
    case green = "Green"
    case orange = "Orange"
    
    var id: String { self.rawValue }
    
    var color: Color {
        switch self {
        case .blue:
            return .blue
        case .red:
            return .red
        case .green:
            return .green
        case .orange:
            return .orange
        }
    }
}


struct SettingsView: View {
    // This property reads/writes the selected color name to UserDefaults.
    @AppStorage("selectedAccentColor") private var selectedColor: AccentColor = .blue
    
    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                // The Picker is bound directly to the AppStorage variable.
                Picker("Accent Color", selection: $selectedColor) {
                    ForEach(AccentColor.allCases) { color in
                        Text(color.rawValue).tag(color)
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}


