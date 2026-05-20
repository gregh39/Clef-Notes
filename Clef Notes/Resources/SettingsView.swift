// Clef Notes/Theme System/SettingsView.swift

import SwiftUI
import CoreData

// An enum to represent the available tint colors
enum AccentColor: String, CaseIterable, Identifiable {
    case blue = "Blue", red = "Red", green = "Green", orange = "Orange"
    case purple = "Purple", pink = "Pink", teal = "Teal", yellow = "Yellow"
    case custom = "Custom"
    
    var id: String { self.rawValue }
    
    var color: Color? {
        switch self {
        case .blue: return .blue
        case .red: return .red
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        case .teal: return .teal
        case .yellow: return .yellow
        case .custom: return nil // Custom color is handled separately in SettingsManager
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StudentCD.name, ascending: true)],
        animation: .default)
    private var students: FetchedResults<StudentCD>

    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var isExporting = false

    private let dataExporter = DataExporter()
    
    var body: some View {
        Form {
            Section {
                TextField("Default Session Title", text: $settingsManager.defaultSessionTitle)
            }
            header: { Text("Default Session Title") }
            footer: { Text("Enter the default name for new practice sessions") }
            
            Section(header: Text("Tools")) {
                Stepper(value: $settingsManager.a4Frequency, in: 410...470, step: 0.5) {
                    Text("Tuner Calibration (A4): \(settingsManager.a4Frequency, specifier: "%.1f") Hz")
                }
                
                Stepper(value: $settingsManager.tunerTransposition, in: -12...12, step: 1) {
                    Text("Tuner Transposition: \(settingsManager.tunerTransposition) semitones")
                }
            }
            
            Section(header: Text("Data Management")) {
                Button {
                    isExporting = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        let url = dataExporter.exportAllDataToJSON(context: viewContext)
                        DispatchQueue.main.async {
                            isExporting = false
                            exportURL = url
                            showingExportSheet = url != nil
                        }
                    }
                } label: {
                    if isExporting {
                        HStack {
                            ProgressView().padding(.trailing, 4)
                            Text("Exporting…")
                        }
                    } else {
                        Label("Export All Data as JSON", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting)
            }
            
            Section(header: Text("About")) {
                Link("Privacy Policy", destination: URL(string: "https://www.clefnotes.app/privacy")!)
                Link("Feedback", destination: URL(string: "mailto:feedback@clefnotes.app")!)
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

