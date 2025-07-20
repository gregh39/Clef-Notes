import SwiftUI

// The custom ViewModifier that now holds a single menu
struct GlobalToolsModifier: ViewModifier {
    @Binding var showingSettingsSheet: Bool
    @Binding var showingMetronome: Bool
    @Binding var showingTuner: Bool

    func body(content: Content) -> some View {
        // The modifier no longer adds its own toolbar. It just handles the sheets.
        content
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

extension View {
    // --- THIS IS THE FIX: The extension now requires the bindings to be passed in ---
    func withGlobalTools(
        showingSettings: Binding<Bool>,
        showingMetronome: Binding<Bool>,
        showingTuner: Binding<Bool>
    ) -> some View {
        self.modifier(GlobalToolsModifier(
            showingSettingsSheet: showingSettings,
            showingMetronome: showingMetronome,
            showingTuner: showingTuner
        ))
    }
}

