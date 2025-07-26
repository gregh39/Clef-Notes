import SwiftUI

struct SideMenuView: View {
    @ObservedObject var student: StudentCD
    @Binding var isPresented: Bool
    @EnvironmentObject var subscriptionManager: SubscriptionManager


    // Bindings for sheets that are NOT part of the navigation
    @Binding var showingEditStudentSheet: Bool
    @Binding var isSharePresented: Bool

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                // Header with student info
                VStack(alignment: .leading) {
                    Text(student.name ?? "Student")
                        .font(.largeTitle)
                        .bold()
                    Text(student.instrument ?? "No Instrument")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding()

                // List with sections and navigation links
                List {
                    Section("Student Actions") {
                        Button {
                            isPresented = false // Dismiss this sheet first
                            // Use a slight delay to ensure the sheet is dismissed before presenting the next one
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingEditStudentSheet = true
                            }
                        } label: {
                            Label("Edit Student", systemImage: "pencil")
                        }

                        Button {
                            isPresented = false // Dismiss this sheet first
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSharePresented = true
                            }
                        } label: {
                            Label("Share Student", systemImage: "square.and.arrow.up")
                        }
                    }

                    Section("Tools") {
                        NavigationLink(destination: MetronomeSectionView()) {
                            Label("Metronome", systemImage: "metronome")
                        }
                        .disabled(!subscriptionManager.canAccessPaidFeatures) // Add this

                        NavigationLink(destination: TunerTabView()) {
                            Label("Tuner", systemImage: "tuningfork")
                        }
                        .disabled(!subscriptionManager.canAccessPaidFeatures) // And this
                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
