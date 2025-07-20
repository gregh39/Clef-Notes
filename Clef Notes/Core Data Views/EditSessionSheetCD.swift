import SwiftUI
import CoreData

struct EditSessionSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var session: PracticeSessionCD

    // The FetchRequest is now a standard property.
    @FetchRequest private var instructors: FetchedResults<InstructorCD>

    @State private var title: String = ""
    @State private var selectedInstructor: InstructorCD?
    @State private var selectedLocation: LessonLocation?
    @State private var date: Date = .now

    // A new initializer to set up the filtered FetchRequest.
    init(session: PracticeSessionCD) {
        self.session = session
        
        // This predicate ensures only instructors for the session's student are fetched.
        let studentPredicate: NSPredicate
        if let student = session.student {
            studentPredicate = NSPredicate(format: "student == %@", student)
        } else {
            // A fallback to fetch no instructors if the session has no student.
            studentPredicate = NSPredicate(value: false)
        }
        
        self._instructors = FetchRequest<InstructorCD>(
            sortDescriptors: [NSSortDescriptor(keyPath: \InstructorCD.name, ascending: true)],
            predicate: studentPredicate
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Session Info")) {
                    TextField("Title", text: $title)
                    Picker("Instructor", selection: $selectedInstructor) {
                        Text("None").tag(Optional<InstructorCD>.none)
                        // This list is now correctly filtered.
                        ForEach(instructors) { instructor in
                            Text(instructor.name ?? "Unknown").tag(Optional(instructor))
                        }
                    }
                    Picker("Location", selection: $selectedLocation) {
                        Text("None").tag(Optional<LessonLocation>.none)
                        ForEach(LessonLocation.allCases, id: \.self) { location in
                            Text(location.rawValue).tag(Optional(location))
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        session.title = title
                        session.instructor = selectedInstructor
                        session.location = selectedLocation
                        session.day = date
                        
                        try? viewContext.save()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                title = session.title ?? ""
                selectedInstructor = session.instructor
                selectedLocation = session.location
                date = session.day ?? .now
            }
        }
    }
}
