import SwiftUI
import CoreData

struct SideMenuView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StudentCD.name, ascending: true)],
        animation: .default)
    private var students: FetchedResults<StudentCD>

    @Binding var selectedStudent: StudentCD?
    @Binding var isPresented: Bool
    @Binding var showingAddStudentSheet: Bool
    let student: StudentCD? // The currently selected student

    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var showingEditStudentSheet = false
    @State private var isSharePresented = false
    @State private var showAllStudents = false

    var body: some View {
        NavigationView {
            List {
                if let student = selectedStudent {
                    Section("Active Student") {
                        StudentCellView(student: student, isSelected: true)
                    }
                }

                Section {
                    DisclosureGroup("Switch Student", isExpanded: $showAllStudents) {
                        ForEach(students) { student in
                            Button(action: {
                                selectedStudent = student
                            }) {
                                HStack {
                                    StudentListRow(student: student)
                                    Spacer()
                                    if student == selectedStudent {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }

                    Button(action: {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showingAddStudentSheet = true
                        }
                    }) {
                        Label("Add New Student", systemImage: "plus")
                    }
                }

                if let student = student {
                    Section("Actions for \(student.name ?? "Student")") {
                        Button {
                            showingEditStudentSheet = true
                        } label: {
                            Label("Edit Student", systemImage: "pencil")
                        }

                        Button {
                            isSharePresented = true
                        } label: {
                            Label("Share Student", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                
                Section("Account") {
                    NavigationLink(destination: SubscriptionView()) {
                        Label("Manage Subscription", systemImage: "creditcard.fill")
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
            .listStyle(.insetGrouped)
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingEditStudentSheet) {
                if let student = student {
                    EditStudentSheetCD(student: student)
                }
            }
            .sheet(isPresented: $isSharePresented) {
                if let student = student {
                    CloudSharingView(student: student)
                }
            }
        }
    }
}

private struct StudentListRow: View {
    @ObservedObject var student: StudentCD

    var body: some View {
        HStack(spacing: 12) {
            if let avatarData = student.avatar, let uiImage = UIImage(data: avatarData) {
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
                HStack {
                    Text(student.name ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(.primary)
                    if student.isShared {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.secondary)
                    }
                }
                Text(student.instrument ?? "No Instrument")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    // This struct provides the content for the preview.
    struct SideMenuView_Preview: View {
        // State variables to manage the preview's behavior.
        @State private var selectedStudent: StudentCD?
        @State private var isPresented = true
        @State private var showingAddStudentSheet = false
        
        // The view context from the preview persistence controller.
        private let viewContext = PersistenceController.preview.persistentContainer.viewContext
        
        @FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \StudentCD.name, ascending: true)],
            animation: .default)
        private var students: FetchedResults<StudentCD>

        var body: some View {
            SideMenuView(
                selectedStudent: $selectedStudent,
                isPresented: $isPresented,
                showingAddStudentSheet: $showingAddStudentSheet,
                student: selectedStudent
            )
            .environment(\.managedObjectContext, viewContext)
            .environmentObject(SubscriptionManager.shared)
            .onAppear {
                // The sample data is now created in PersistenceController.preview
                // We just need to set the initial selected student.
                selectedStudent = students.first
            }
        }
    }
    
    // Return the preview struct.
    return SideMenuView_Preview()
}
