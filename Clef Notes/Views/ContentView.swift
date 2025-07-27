// Clef Notes/Views/ContentView.swift

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

    var body: some View {
        if let student = students.first {
            // If at least one student exists, show the detail view for the first one.
            //NavigationStack {
            StudentDetailViewCD(student: student)
            //}
        } else {
            // If no students exist, show the view to add a new student.
            NavigationSplitView {
                studentListView
            } detail: {
                Text("Select a student")
            }
            .sheet(isPresented: $showingAddSheet) {
                addStudentSheet
            }
        }
    }

    private var studentListView: some View {
        List {
            Text("No students available. Please add a student to begin.")
        }
        .navigationTitle("Students")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Student", systemImage: "plus")
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
