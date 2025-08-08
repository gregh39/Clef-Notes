import SwiftUI
import CoreData
import TelemetryDeck

struct EditSessionSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var session: PracticeSessionCD

    @FetchRequest private var instructors: FetchedResults<InstructorCD>
    
    @State private var sessionTitle: String = ""
    @State private var sessionDate: Date = .now
    @State private var selectedLocation: LessonLocation?
    @State private var selectedInstructor: InstructorCD?
    @State private var durationMinutes: Int = 0
    
    @State private var showingAddInstructorSheet = false
    @State private var newInstructorName: String = ""

    init(session: PracticeSessionCD) {
        self.session = session
        
        let predicate = NSPredicate(format: "student == %@", session.student!)
        
        self._instructors = FetchRequest<InstructorCD>(
            sortDescriptors: [NSSortDescriptor(keyPath: \InstructorCD.name, ascending: true)],
            predicate: predicate
        )
    }

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section("Session Name") {
                        TextField("Session Title", text: $sessionTitle)
                    }

                    Section("Session Details") {
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
                        Stepper(value: $durationMinutes, in: 0...1440) {
                            HStack {
                                Label("Duration", systemImage: "clock")
                                Spacer()
                                Text("\(durationMinutes) min")
                            }
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
                        Button("Add New Instructor") {
                            showingAddInstructorSheet = true
                        }
                    }
                }
                .addDoneButtonToKeyboard()

                SaveButtonView(title: "Save Changes", action: saveChanges)
            }
            .navigationTitle("Edit Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                sessionTitle = session.title ?? ""
                sessionDate = session.day ?? .now
                selectedLocation = session.location
                selectedInstructor = session.instructor
                durationMinutes = Int(session.durationMinutes)
            }
            .sheet(isPresented: $showingAddInstructorSheet) {
                addInstructorSheet
            }
        }
    }
    
    private var addInstructorSheet: some View {
        NavigationStack {
            VStack {
                Form {
                    TextField("Instructor Name", text: $newInstructorName)
                }
                SaveButtonView(title: "Add Instructor", action: {
                    let instructor = InstructorCD(context: viewContext)
                    instructor.name = newInstructorName
                    instructor.student = session.student
                    try? viewContext.save()
                    selectedInstructor = instructor
                    showingAddInstructorSheet = false
                }, isDisabled: newInstructorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("New Instructor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddInstructorSheet = false
                    }
                }
            }
        }
    }

    private func saveChanges() {
        session.title = sessionTitle
        session.day = sessionDate
        session.location = selectedLocation
        session.instructor = selectedInstructor
        session.durationMinutes = Int64(durationMinutes)

        do {
            try viewContext.save()
            TelemetryDeck.signal("session_edited")
            dismiss()
        } catch {
            TelemetryDeck.signal("session_edit_failed")
            print("Failed to save session changes: \(error)")
        }
    }
}

