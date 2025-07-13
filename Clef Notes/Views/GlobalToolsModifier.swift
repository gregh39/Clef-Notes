import SwiftUI

// The custom ViewModifier that now holds a single menu
struct GlobalToolsModifier: ViewModifier {
    @State private var showingSettingsSheet = false
    @State private var showingMetronome = false
    @State private var showingTuner = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        // Button to show Settings
                        Button(action: { showingSettingsSheet = true }) {
                            Label("Settings", systemImage: "gearshape")
                        }
                        
                        // Button to show the Metronome
                        Button(action: { showingMetronome = true }) {
                            Label("Metronome", systemImage: "metronome")
                        }
                        
                        // Button to show the Tuner
                        Button(action: { showingTuner = true }) {
                            Label("Tuner", systemImage: "tuningfork")
                        }
                    } label: {
                        // This is the icon for the menu button itself
                        Label("Menu", systemImage: "line.3.horizontal")
                    }
                }
            }
            .sheet(isPresented: $showingSettingsSheet) {
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingSettingsSheet = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingMetronome) {
                MetronomeSectionView()
            }
            .sheet(isPresented: $showingTuner) {
                TunerTabView()
            }
    }
}

// The extension remains the same
extension View {
    func withGlobalTools() -> some View {
        self.modifier(GlobalToolsModifier())
    }
}
