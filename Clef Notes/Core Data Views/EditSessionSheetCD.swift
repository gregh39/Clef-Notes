import SwiftUI
import CoreData

struct EditSessionSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var session: PracticeSessionCD

    @FetchRequest private var instructors: FetchedResults<InstructorCD>

    @State private var title: String = ""
    @State private var selectedInstructor: InstructorCD?
    @State private var selectedLocation: LessonLocation?
    @State private var date: Date = .now

    init(session: PracticeSessionCD) {
        self.session = session
        
        let studentPredicate: NSPredicate
        if let student = session.student {
            studentPredicate = NSPredicate(format: "student == %@", student)
        } else {
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
                // --- THIS IS THE FIX: Section is updated with header and footer text ---
                Section {
                    TextField("Session Title", text: $title)
                    DatePicker(selection: $date, displayedComponents: .date) {
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
                    Text("Update the title, date, or location for this practice session.")
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
