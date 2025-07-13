import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Student.name) private var students: [Student]

    @State private var selectedStudent: Student?
    @State private var showingAddSheet = false
    
    // The showingSettingsSheet state is no longer needed here
    
    @State private var newName = ""
    @State private var newInstrument = ""

    var body: some View {
        NavigationSplitView {
            List(students, id: \.id, selection: $selectedStudent) { student in
                NavigationLink(value: student) {
                    VStack(alignment: .leading) {
                        Text(student.name)
                            .font(.headline)
                        Text(student.instrument)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Students")
            .toolbar {
                // The settings button is now gone, handled by the modifier
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    EditButton()
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Student", systemImage: "plus")
                    }
                }
            }
            .withGlobalTools() // <-- This single modifier adds the new menu
        } detail: {
            if let student = selectedStudent {
                StudentDetailView(student: student, context: modelContext)
            } else {
                Text("Select a student")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                Form {
                    TextField("Name", text: $newName)
                    TextField("Instrument", text: $newInstrument)
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
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  newInstrument.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        // The sheet modifier for settings is also gone from here
    }

    private func addStudent() {
        let student = Student(name: newName, instrument: newInstrument)
        modelContext.insert(student)
    }

    private func clearForm() {
        newName = ""
        newInstrument = ""
    }
}
#Preview {
    ContentView()
        .modelContainer(for: Student.self, inMemory: true)
}
