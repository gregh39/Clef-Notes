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
    @State private var newName = ""
    @State private var newInstrument: Instrument? = nil
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var selectedAvatarData: Data?
    
    @State private var selectedStudent: StudentCD?
    @AppStorage("selectedStudentID") private var selectedStudentID: String?
    @State private var showingSideMenu = false

    // This property tracks if the user has completed the onboarding flow.
    // It's stored in UserDefaults and will persist across app launches.
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
        }
        .sheet(isPresented: $showingAddSheet) {
            addStudentSheet
        }
        
        .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
            // This presents the OnboardingView if the flag is false.
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
        .onAppear {
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
    
    private var addStudentSheet: some View {
        NavigationStack {
            Form {
                Section("Avatar") {
                    HStack {
                        Spacer()
                        VStack {
                            if let avatarData = selectedAvatarData, let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundColor(.gray)
                            }
                            PhotosPicker("Choose Avatar", selection: $selectedAvatarItem, matching: .images)
                                .buttonStyle(.bordered)
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                }
                
                Section("Student Details") {
                    TextField("Name", text: $newName)
                    Picker("Instrument", selection: $newInstrument) {
                        Text("Select an Instrument").tag(Optional<Instrument>.none)
                        ForEach(instrumentSections) { section in
                            Section(header: Text(section.name)) {
                                ForEach(section.instruments) { instrument in
                                    Text(instrument.rawValue).tag(Optional(instrument))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Student")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddSheet = false
                        clearForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addStudent()
                        showingAddSheet = false
                        clearForm()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newInstrument == nil)
                }
            }
        }
        .onChange(of: selectedAvatarItem) {
            Task {
                if let data = try? await selectedAvatarItem?.loadTransferable(type: Data.self) {
                    selectedAvatarData = data
                }
            }
        }
    }

    private func addStudent() {
        let newStudent = StudentCD(context: viewContext)
        newStudent.id = UUID()
        newStudent.name = newName
        newStudent.instrumentType = newInstrument
        newStudent.avatar = selectedAvatarData
        do {
            try viewContext.save()
            selectedStudent = newStudent
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func clearForm() {
        newName = ""
        newInstrument = nil
        selectedAvatarItem = nil
        selectedAvatarData = nil
    }
}

