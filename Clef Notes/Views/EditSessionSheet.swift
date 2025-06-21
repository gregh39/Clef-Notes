import SwiftUI
import SwiftData

struct EditSessionSheet: View {
    @Binding var isPresented: Bool
    @Bindable var session: PracticeSession
    var context: ModelContext
    var onSave: (() -> Void)? = nil

    @State private var title: String = ""
    @Query private var instructors: [Instructor]
    @State private var selectedInstructor: Instructor? = nil
    @State private var selectedLocation: LessonLocation? = nil
    @State private var date: Date = Date()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Session Info")) {
                    TextField("Title", text: $title)
                    Picker("Instructor", selection: $selectedInstructor) {
                        Text("None").tag(Optional<Instructor>.none)
                        ForEach(instructors, id: \.self) { instructor in
                            Text(instructor.name).tag(Optional(instructor))
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        session.title = title
                        session.instructor = selectedInstructor
                        session.location = selectedLocation
                        session.day = date
                        try? context.save()
                        onSave?()
                        isPresented = false
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                // Populate local state from session data ONLY ON FIRST APPEAR
                title = session.title ?? ""
                selectedInstructor = session.instructor
                selectedLocation = session.location
                date = session.day
            }
        }
    }
}
