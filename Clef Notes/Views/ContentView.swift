import SwiftUI
import SwiftData
import CoreData

struct ContentView: View {
    // --- CHANGE 1: Get both data contexts from the environment ---
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.modelContext) private var modelContext
    
    // --- CHANGE 2: Fetch students from Core Data instead of Swift Data ---
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StudentCD.name, ascending: true)],
        animation: .default)
    private var students: FetchedResults<StudentCD>

    // --- CHANGE 3: State now holds a Core Data object ---
    @State private var selectedStudent: StudentCD?
    @State private var showingAddSheet = false
    
    @State private var newName = ""
    @State private var newInstrument = ""

    var body: some View {
        NavigationSplitView {
            // --- CHANGE 4: The list now iterates over Core Data objects ---
            List(students, id: \.self, selection: $selectedStudent) { student in
                NavigationLink(value: student) {
                    VStack(alignment: .leading) {
                        Text(student.name ?? "Unknown")
                            .font(.headline)
                        Text(student.instrument ?? "Unknown")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Students")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // EditButton will need to be adapted for Core Data deletion
                    // Button("Edit") { /* ... */ }
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Student", systemImage: "plus")
                    }
                }
            }
            .withGlobalTools()
        } detail: {
            if let student = selectedStudent {
                // The detail view now uses our new Core Data-ready view
                StudentDetailViewCD(student: student)
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
        // --- CHANGE 5: Trigger the migration when the view first appears ---
        .onAppear {
            DataMigrator.migrate(from: modelContext, to: viewContext)
        }
    }

    // --- CHANGE 6: Update add/delete functions for Core Data ---
    private func addStudent() {
        let newStudent = StudentCD(context: viewContext)
        newStudent.id = UUID()
        newStudent.name = newName
        newStudent.instrument = newInstrument

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    private func clearForm() {
        newName = ""
        newInstrument = ""
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
