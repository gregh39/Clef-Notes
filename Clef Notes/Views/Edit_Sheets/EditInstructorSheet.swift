import SwiftUI
import CoreData

struct EditInstructorSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var instructor: InstructorCD

    @State private var name: String = ""

    var body: some View {
        VStack {
            Form {
                Section("Instructor Details") {
                    TextField("Name", text: $name)
                }
            }
            SaveButtonView(title: "Save Changes", action: saveChanges, isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .navigationTitle("Edit Instructor")
        .onAppear {
            name = instructor.name ?? ""
        }
    }

    private func saveChanges() {
        instructor.name = name
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save instructor changes: \(error)")
        }
    }
}
