import SwiftUI

struct SideMenuView: View {
    @Binding var student: StudentCD
    @Binding var isPresented: Bool
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StudentCD.name, ascending: true)],
        animation: .default)
    private var students: FetchedResults<StudentCD>

    // Bindings for sheets that are NOT part of the navigation
    @Binding var showingEditStudentSheet: Bool
    @Binding var isSharePresented: Bool
    
    @State private var isStudentListExpanded: Bool = false

    var body: some View {
        NavigationView {
            // The content is now wrapped in a List to get the desired styling
            List {
                // Section for the header content
                Section {
                    DisclosureGroup(isExpanded: $isStudentListExpanded) {
                        ForEach(students) { aStudent in
                            if aStudent != student {
                                Button(action: {
                                    student = aStudent
                                    isStudentListExpanded = false
                                }) {
                                    HStack {
                                        if let avatarData = aStudent.avatar, let uiImage = UIImage(data: avatarData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.secondary)
                                        }
                                        VStack(alignment: .leading) {
                                            Text(aStudent.name ?? "Student")
                                                .font(.headline)
                                            Text(aStudent.instrument ?? "No Instrument")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } label: {
                        HStack(spacing: 15) {
                            if let avatarData = student.avatar, let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(student.name ?? "Student")
                                    .font(.title2)
                                    .bold()
                                Text(student.instrument ?? "No Instrument")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

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
                    NavigationLink(destination: PitchGameView()) {
                        Label("Pitch Game", systemImage: "gamecontroller")
                    }

                    NavigationLink(destination: MetronomeSectionView()) {
                        Label("Metronome", systemImage: "metronome")
                    }
                    .disabled(!subscriptionManager.canAccessPaidFeatures)

                    NavigationLink(destination: TunerTabView()) {
                        Label("Tuner", systemImage: "tuningfork")
                    }
                    .disabled(!subscriptionManager.canAccessPaidFeatures)
                    
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .listStyle(.insetGrouped) // Explicitly setting the list style
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
