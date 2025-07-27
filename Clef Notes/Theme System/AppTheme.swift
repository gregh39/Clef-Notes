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
    @EnvironmentObject var settingsManager: SettingsManager
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StudentCD.name, ascending: true)],
        animation: .default)
    private var students: FetchedResults<StudentCD>
    
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    
    private let dataExporter = DataExporter()
    
    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $settingsManager.colorSchemeSetting) {
                    ForEach(ColorSchemeSetting.allCases) { scheme in
                        Text(scheme.rawValue).tag(scheme)
                    }
                }
                
                Picker("Accent Color", selection: $settingsManager.accentColor) {
                    ForEach(AccentColor.allCases) { color in
                        Text(color.rawValue).tag(color)
                    }
                }
                
                Picker("App Icon", selection: $settingsManager.appIcon) {
                    ForEach(AppIcon.allCases) { icon in
                        HStack {
                            Image(icon.preview)
                                .resizable()
                                .frame(width: 30, height: 30)
                                .cornerRadius(6)
                            Text(icon.rawValue)
                        }.tag(icon)
                    }
                }
                .onChange(of: settingsManager.appIcon) {
                    settingsManager.setAppIcon()
                }
            }
            
            Section(header: Text("Practice & Session")) {
                TextField("Default Session Title", text: $settingsManager.defaultSessionTitle)
                
                Stepper(value: $settingsManager.defaultSessionDuration, in: 5...180, step: 5) {
                    Text("Default Duration: \(settingsManager.defaultSessionDuration) min")
                }
                
                Toggle("Practice Reminders", isOn: $settingsManager.practiceRemindersEnabled)
                
                if settingsManager.practiceRemindersEnabled {
                    DatePicker("Reminder Time", selection: $settingsManager.practiceReminderTime, displayedComponents: .hourAndMinute)
                }
            }
            
            Section(header: Text("Tools")) {
                Stepper(value: $settingsManager.a4Frequency, in: 410...470, step: 0.5) {
                    Text("Tuner Calibration (A4): \(settingsManager.a4Frequency, specifier: "%.1f") Hz")
                }
                
                Stepper(value: $settingsManager.tunerTransposition, in: -12...12, step: 1) {
                    Text("Tuner Transposition: \(settingsManager.tunerTransposition) semitones")
                }
            }
            
            Section(header: Text("Awards & Notifications")) {
                Toggle("Award Notifications", isOn: $settingsManager.awardNotificationsEnabled)
                Toggle("Enable Weekly Goal", isOn: $settingsManager.weeklyGoalEnabled)
                if settingsManager.weeklyGoalEnabled {
                    Stepper(value: $settingsManager.weeklyGoalMinutes, in: 30...600, step: 15) {
                        Text("Weekly Goal: \(settingsManager.weeklyGoalMinutes) min")
                    }
                }
            }
            
            Section(header: Text("Data Management")) {
                Button("Export All Student Data") {
                    if let student = students.first {
                        exportURL = dataExporter.exportStudentToCSV(student: student)
                        if exportURL != nil {
                            showingExportSheet = true
                        }
                    }
                }
                NavigationLink("Cloud Sync Status") {
                    CloudSyncStatusView()
                }
            }
            
            Section(header: Text("About")) {
                Link("Privacy Policy", destination: URL(string: "https://www.example.com/privacy")!)
                Link("Feedback", destination: URL(string: "mailto:feedback@example.com")!)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
