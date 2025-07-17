import SwiftUI
import CoreData

struct EditSessionSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // --- CHANGE 1: Use @ObservedObject for Core Data objects ---
    @ObservedObject var session: PracticeSessionCD

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \InstructorCD.name, ascending: true)])
    private var instructors: FetchedResults<InstructorCD>

    // --- CHANGE 2: Create local @State variables for editing ---
    @State private var title: String = ""
    @State private var selectedInstructor: InstructorCD?
    @State private var selectedLocation: LessonLocation?
    @State private var date: Date = .now

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Session Info")) {
                    // --- CHANGE 3: Bind controls to local state ---
                    TextField("Title", text: $title)
                    Picker("Instructor", selection: $selectedInstructor) {
                        Text("None").tag(Optional<InstructorCD>.none)
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
                        // --- CHANGE 4: Save local state back to the object ---
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
            // --- CHANGE 5: Populate state when the view appears ---
            .onAppear {
                title = session.title ?? ""
                selectedInstructor = session.instructor
                selectedLocation = session.location
                date = session.day ?? .now
            }
        }
    }
}
