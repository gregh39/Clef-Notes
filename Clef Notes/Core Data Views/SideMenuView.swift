import SwiftUI
import CoreData

struct SideMenuView: View {
    @Environment(\.managedObjectContext) private var viewContext
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
    @State private var studentToDelete: StudentCD?

    // Computed property to sort students with the selected one first
    private var sortedStudents: [StudentCD] {
        students.sorted { (a, b) -> Bool in
            if a == selectedStudent {
                return true
            } else if b == selectedStudent {
                return false
            }
            return a.name ?? "" < b.name ?? ""
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                // Horizontally scrolling student picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Add new student button
                        Button(action: {
                            isPresented = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingAddStudentSheet = true
                            }
                        }) {
                            VStack {
                                Image(systemName: "plus")
                                    .font(.largeTitle)
                                    .foregroundColor(.accentColor)
                                Text("Add New")
                                    .font(.caption)
                            }
                            .frame(width: 100, height: 100)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        }

                        // Student list
                        ForEach(sortedStudents) { student in
                            Button(action: {
                                selectedStudent = student
                            }) {
                                StudentIconView(student: student, isSelected: self.selectedStudent == student)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    studentToDelete = student
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding()
                }

                // The rest of the menu
                List {
                    if let student = student {
                        Section {
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
                        } header: {
                            Text("Actions for \(student.name ?? "Student")")
                        } footer: {
                            Text("Long-press on a student's icon above to delete them.")
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
                        
                        NavigationLink(destination: ThemeView()) {
                            Label("Appearance", systemImage: "paintpalette.fill")
                        }
                        
                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "gearshape.fill")
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
            .alert("Delete \(studentToDelete?.name ?? "Student")?",
                   isPresented: Binding(get: { studentToDelete != nil }, set: { if !$0 { studentToDelete = nil } }),
                   presenting: studentToDelete)
            { student in
                Button("Delete", role: .destructive) {
                    deleteStudent(student)
                }
                Button("Cancel", role: .cancel) { }
            } message: { _ in
                Text("Are you sure you want to delete this student? All of their data will be removed. This action cannot be undone.")
            }
        }
    }
    
    private func deleteStudent(_ student: StudentCD) {
        let studentWasSelected = (student == selectedStudent)
        
        viewContext.delete(student)
        
        do {
            try viewContext.save()
            
            if studentWasSelected {
                selectedStudent = students.first
            }
            
            if students.isEmpty {
                isPresented = false
            }
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

// New rectangular student icon view
private struct StudentIconView: View {
    @ObservedObject var student: StudentCD
    var isSelected: Bool

    var body: some View {
        VStack {
            if let avatarData = student.avatar, let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Image(systemName: "person.fill")
                    .font(.largeTitle)
                    .frame(width: 80, height: 80)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text(student.name ?? "Unknown")
                .font(.caption)
                .lineLimit(1)
            Text(student.instrument ?? "")
                .font(.caption2)
                .lineLimit(1)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
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
