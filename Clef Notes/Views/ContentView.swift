import SwiftUI
import CoreData
import PhotosUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StudentCD.name, ascending: true)],
        animation: .default)
    private var students: FetchedResults<StudentCD>

    @State private var showingAddSheet = false

    @EnvironmentObject var settingsManager: SettingsManager

    @State private var selectedStudent: StudentCD?
    @AppStorage("selectedStudentID") private var selectedStudentID: String?
    @State private var showingSideMenu = false

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            // If a student is selected, show their detail view.
            if let student = selectedStudent {
                NavigationStack {
                    StudentDetailNavigationView(student: student, showingSideMenu: $showingSideMenu)
                }
            } else {
                // Otherwise, show the appropriate placeholder/selection view.
                noStudentView
            }
        }
        .sheet(isPresented: $showingSideMenu) {
            SideMenuView(selectedStudent: $selectedStudent, isPresented: $showingSideMenu, showingAddStudentSheet: $showingAddSheet, student: selectedStudent)
                .presentationSizing(.page)
                .preferredColorScheme(settingsManager.colorSchemeSetting.colorScheme)
        }
        .presentationSizing(.page)
        .sheet(isPresented: $showingAddSheet) {
            AddStudentSheetCD(isPresented: $showingAddSheet, selectedStudent: $selectedStudent)
        }
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
        .onAppear {
            // On launch, try to restore the last selected student.
            if let studentID = selectedStudentID,
               let student = students.first(where: { $0.id?.uuidString == studentID }) {
                selectedStudent = student
            }
        }
        .onChange(of: students.count) {
            // When the student list changes (e.g., after initial sync),
            // if no student is selected, select the first one automatically.
            if selectedStudent == nil, let firstStudent = students.first {
                selectedStudent = firstStudent
            }
        }
        .onChange(of: selectedStudent) {
            // When the selection changes, save it for the next launch.
            selectedStudentID = selectedStudent?.id?.uuidString
        }
    }

    // This view is shown when selectedStudent is nil.
    @ViewBuilder
    private var noStudentView: some View {
        NavigationStack {
            VStack {
                // If the database is completely empty.
                if students.isEmpty {
                    Spacer()
                    Image(systemName: "music.mic")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                    Text("No Students")
                        .font(.largeTitle.bold())
                    Text("Add your first student to get started.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                    Button("Add First Student") {
                        showingAddSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom)
                } else {
                    // If students exist but none are selected yet.
                    Spacer()
                    Text("Select a Student")
                        .font(.largeTitle.bold())
                        .padding(.bottom, 2)
                    Text("Tap a student below to view their details.")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // "Add New" button, styled like in SideMenuView
                            Button(action: {
                                showingAddSheet = true
                            }) {
                                VStack {
                                    Image(systemName: "plus")
                                        .font(.largeTitle)
                                        .foregroundColor(.accentColor)
                                    Text("Add New")
                                        .font(.caption)
                                }
                                .frame(width: 100, height: 120) // Adjusted height for consistency
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                            }

                            // Student list using StudentIconView
                            ForEach(students) { student in
                                Button(action: {
                                    // Tapping a student selects them, causing the main body to switch views.
                                    selectedStudent = student
                                }) {
                                    StudentIconView(student: student, isSelected: false)
                                }
                            }
                        }
                        .padding()
                    }
                    .frame(height: 150)
                    Spacer()
                }
            }
            .navigationTitle("Clef Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSideMenu = true }) {
                        Label("Menu", systemImage: "line.3.horizontal")
                    }
                }
            }
        }
    }
}

// MARK: - Student Icon View
// This view is an exact copy from your SideMenuView to ensure identical appearance.
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
                    .font(.system(size: 40))
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
        .frame(width: 100, height: 120)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
