import SwiftUI
import SwiftData
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.modelContext) private var modelContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StudentCD.name, ascending: true)],
        animation: .default)
    private var students: FetchedResults<StudentCD>

    @State private var selectedStudent: StudentCD?
    @State private var showingAddSheet = false
    
    // --- CHANGE 1: State to manage the delete confirmation ---
    @State private var offsetsToDelete: IndexSet?
    
    @State private var newName = ""
    @State private var newInstrument = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedStudent) {
                ForEach(students) { student in
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
                // --- CHANGE 2: The onDelete modifier now sets the state to trigger the alert ---
                .onDelete(perform: { offsets in
                    self.offsetsToDelete = offsets
                })
            }
            .navigationTitle("Students")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    EditButton()
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Add Student", systemImage: "plus")
                    }
                }
            }
            .withGlobalTools()
            // --- CHANGE 3: The alert modifier to show the confirmation ---
            .alert("Delete Student?",
                   isPresented: .constant(offsetsToDelete != nil),
                   actions: {
                        Button("Delete", role: .destructive) {
                            if let offsets = offsetsToDelete {
                                deleteStudents(offsets: offsets)
                            }
                            offsetsToDelete = nil
                        }
                        Button("Cancel", role: .cancel) {
                            offsetsToDelete = nil
                        }
                   },
                   message: {
                        Text("This will permanently delete the student and all of their songs, sessions, and plays. This action cannot be undone.")
                   })
        } detail: {
            if let student = selectedStudent {
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
        .onAppear {
            DataMigrator.migrate(from: modelContext, to: viewContext)
        }
    }

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
    
    private func deleteStudents(offsets: IndexSet) {
        withAnimation {
            offsets.map { students[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
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
