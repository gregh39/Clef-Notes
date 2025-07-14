import SwiftData
import SwiftUI

struct AddSessionSheet: View {
    @Binding var isPresented: Bool
    let student: Student
    let context: ModelContext
    var onAdd: (PracticeSession) -> Void

    @State private var selectedInstructor: Instructor?
    @State private var selectedLocation: LessonLocation?
    @State private var sessionDate: Date = .now
    @State private var sessionTitle: String = "Practice"
    @Query private var instructors: [Instructor]

    @State private var showingAddInstructorSheet = false
    @State private var newInstructorName: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Session Title", text: $sessionTitle)
                }
                DatePicker("Date", selection: $sessionDate, displayedComponents: [.date])
                Picker("Instructor", selection: $selectedInstructor) {
                    Text("None").tag(Optional<Instructor>.none)
                    ForEach(instructors, id: \.self) { instructor in
                        Text(instructor.name).tag(Optional(instructor))
                    }
                }
                Button("Add Instructor") {
                    showingAddInstructorSheet = true
                }

                Picker("Location", selection: $selectedLocation) {
                    Text("None").tag(Optional<LessonLocation>.none)
                    ForEach(LessonLocation.allCases, id: \.self) { location in
                        Text(location.rawValue).tag(Optional(location))
                    }
                }
            }
            .navigationTitle("New Practice Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let session = PracticeSession(
                            day: sessionDate,
                            durationMinutes: 0,
                            studentID: student.id
                        )
                        session.title = sessionTitle
                        session.student = student
                        session.instructor = selectedInstructor
                        session.location = selectedLocation
                        context.insert(session)
                        try? context.save()
                        onAdd(session)
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddInstructorSheet) {
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
                            let instructor = Instructor(name: newInstructorName)
                            context.insert(instructor)
                            try? context.save()
                            selectedInstructor = instructor
                            showingAddInstructorSheet = false
                        }
                        // --- THIS IS THE FIX ---
                        // Disable the button if the name is empty.
                        .disabled(newInstructorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}
