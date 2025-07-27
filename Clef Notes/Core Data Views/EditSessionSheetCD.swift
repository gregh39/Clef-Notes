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
    
    // State for editing duration
    @State private var hours: String = ""
    @State private var minutes: String = ""


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
                
                // --- THIS IS THE NEW SECTION ---
                Section("Duration") {
                    HStack {
                        TextField("Hours", text: $hours)
                            .keyboardType(.numberPad)
                        Text("hr")
                        TextField("Minutes", text: $minutes)
                            .keyboardType(.numberPad)
                        Text("min")
                    }
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
                        saveChanges()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                // Populate state when the view appears
                title = session.title ?? ""
                selectedInstructor = session.instructor
                selectedLocation = session.location
                date = session.day ?? .now
                
                // Convert total minutes into hours and minutes
                let totalMinutes = session.durationMinutes
                hours = "\(totalMinutes / 60)"
                minutes = "\(totalMinutes % 60)"
            }
        }
    }
    
    private func saveChanges() {
        session.title = title
        session.instructor = selectedInstructor
        session.location = selectedLocation
        session.day = date
        
        // Convert hours and minutes back to total minutes
        let hoursInMinutes = (Int64(hours) ?? 0) * 60
        let minutesValue = Int64(minutes) ?? 0
        session.durationMinutes = hoursInMinutes + minutesValue
        
        try? viewContext.save()
    }
}
