import SwiftUI
import CoreData

struct AddSessionSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let student: StudentCD
    var onAdd: (PracticeSessionCD) -> Void

    @FetchRequest private var instructors: FetchedResults<InstructorCD>

    @State private var selectedInstructor: InstructorCD?
    @State private var selectedLocation: LessonLocation?
    @State private var sessionDate: Date = .now
    @State private var sessionTitle: String = "Practice"
    
    @State private var showingAddInstructorSheet = false
    @State private var newInstructorName: String = ""

    init(student: StudentCD, onAdd: @escaping (PracticeSessionCD) -> Void) {
        self.student = student
        self.onAdd = onAdd
        
        let predicate = NSPredicate(format: "student == %@", student)
        
        self._instructors = FetchRequest<InstructorCD>(
            sortDescriptors: [NSSortDescriptor(keyPath: \InstructorCD.name, ascending: true)],
            predicate: predicate
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // --- THIS IS THE FIX: A footer is added to the section ---
                Section {
                    TextField("Session Title", text: $sessionTitle)
                    DatePicker(selection: $sessionDate, displayedComponents: [.date]) {
                        Label("Date", systemImage: "calendar")
                    }
                    Picker(selection: $selectedLocation) {
                        Text("None").tag(Optional<LessonLocation>.none)
                        ForEach(LessonLocation.allCases, id: \.self) { location in
                            Text(location.rawValue).tag(Optional(location))
                        }
                    } label: {
                        Label("Location", systemImage: "mappin.and.ellipse")
                    }
                } header: {
                    Text("Session Details")
                } footer: {
                    Text("The session title defaults to 'Practice' but can be changed to whatever you like.")
                }

                Section("Instructor") {
                    Picker(selection: $selectedInstructor) {
                        Text("None").tag(Optional<InstructorCD>.none)
                        ForEach(instructors) { instructor in
                            Text(instructor.name ?? "Unknown").tag(Optional(instructor))
                        }
                    } label: {
                        Label("Instructor", systemImage: "person.fill")
                    }
                    Button("Add New Instructor") {
                        showingAddInstructorSheet = true
                    }
                }
            }
            .navigationTitle("New Practice Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSession()
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddInstructorSheet) {
            addInstructorSheet
        }
    }
    
    private var addInstructorSheet: some View {
        NavigationStack {
            Form {
                TextField("Instructor Name", text: $newInstructorName)
            }
            .navigationTitle("New Instructor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddInstructorSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let instructor = InstructorCD(context: viewContext)
                        instructor.name = newInstructorName
                        instructor.student = student
                        try? viewContext.save()
                        selectedInstructor = instructor
                        showingAddInstructorSheet = false
                    }
                    .disabled(newInstructorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addSession() {
        let newSession = PracticeSessionCD(context: viewContext)
        newSession.day = sessionDate
        newSession.durationMinutes = 0
        newSession.studentID = student.id
        newSession.title = sessionTitle
        newSession.student = student
        newSession.instructor = selectedInstructor
        newSession.location = selectedLocation
        
        do {
            try viewContext.save()
            onAdd(newSession)
        } catch {
            print("Failed to save new session: \(error)")
        }
    }
}
