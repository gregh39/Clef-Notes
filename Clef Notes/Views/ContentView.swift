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
            if let student = selectedStudent {
                NavigationStack(){
                    StudentDetailNavigationView(student: student, showingSideMenu: $showingSideMenu)
                }
            } else {
                noStudentView
            }
        }
        .sheet(isPresented: $showingSideMenu) {
            SideMenuView(selectedStudent: $selectedStudent, isPresented: $showingSideMenu, showingAddStudentSheet: $showingAddSheet, student: selectedStudent)
                .presentationSizing(.page)
                .preferredColorScheme(settingsManager.colorSchemeSetting.colorScheme) // <<< ADD THIS

        }
        .sheet(isPresented: $showingAddSheet) {
            AddStudentSheetCD(isPresented: $showingAddSheet, selectedStudent: $selectedStudent)
        }
        
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
        .onAppear {
            let fetchRequest = UsageTrackerCD.fetchRequest()
            if let trackers = try? viewContext.fetch(fetchRequest) {
                for tracker in trackers {
                    print("UsageTrackerCD: totalStudentsCreated=\(tracker.totalStudentsCreated), totalSessionsCreated=\(tracker.totalSessionsCreated), totalSongsCreated=\(tracker.totalSongsCreated)")
                }
            } else {
                print("Failed to fetch UsageTrackerCD entities")
            }
            
            if let studentID = selectedStudentID,
               let student = students.first(where: { $0.id?.uuidString == studentID }) {
                selectedStudent = student
            } else if !students.isEmpty {
                selectedStudent = students.first
            }
        }
        .onChange(of: selectedStudent) {
            selectedStudentID = selectedStudent?.id?.uuidString
        }
    }

    private var noStudentView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            Text("No Student Selected")
                .font(.largeTitle.bold())
            Text("Add a new student or select one from the menu to get started.")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Add First Student") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .navigationTitle("Clef Notes")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingSideMenu = true
                }) {
                    Label("Menu", systemImage: "line.3.horizontal")
                }
            }
        }
    }
}
