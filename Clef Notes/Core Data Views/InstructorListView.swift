import SwiftUI
import CoreData

struct InstructorListView: View {
    @ObservedObject var student: StudentCD
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest private var instructors: FetchedResults<InstructorCD>

    @State private var showingAddInstructorSheet = false

    init(student: StudentCD) {
        self.student = student
        let predicate = NSPredicate(format: "student == %@", student)
        self._instructors = FetchRequest<InstructorCD>(
            sortDescriptors: [NSSortDescriptor(keyPath: \InstructorCD.name, ascending: true)],
            predicate: predicate
        )
    }

    var body: some View {
        Group {
            if instructors.isEmpty {
                ContentUnavailableView {
                    Label("No Instructors Yet", systemImage: "person.badge.plus")
                } description: {
                    Text("Tap the '+' button to add your first instructor.")
                }
            } else {
                List {
                    ForEach(instructors) { instructor in
                        NavigationLink(destination: EditInstructorSheet(instructor: instructor)) {
                            InstructorRowView(instructor: instructor)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteInstructor(instructor)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
                .navigationTitle("Instructors")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingAddInstructorSheet = true
                        }) {
                            Label("Add Instructor", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddInstructorSheet) {
                    AddInstructorSheet(student: student)
                }
            
        
    }

    private func deleteInstructor(_ instructor: InstructorCD) {
        viewContext.delete(instructor)
        do {
            try viewContext.save()
        } catch {
            // Handle the error appropriately
            print("Error deleting instructor: \(error)")
        }
    }
}

struct InstructorRowView: View {
    @ObservedObject var instructor: InstructorCD

    var body: some View {
        HStack {
            Image(systemName: "person.fill")
                .font(.title)
                .foregroundColor(.accentColor)
                .frame(width: 40)
            VStack(alignment: .leading) {
                Text(instructor.name ?? "Unknown Instructor")
                    .font(.headline)
                Text("Taught \(instructor.sessionsArray.count) sessions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct AddInstructorSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let student: StudentCD

    @State private var newInstructorName = ""

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    TextField("Instructor Name", text: $newInstructorName)
                }
                SaveButtonView(title: "Add Instructor", action: {
                    let instructor = InstructorCD(context: viewContext)
                    instructor.name = newInstructorName
                    instructor.student = student
                    try? viewContext.save()
                    dismiss()
                }, isDisabled: newInstructorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("New Instructor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
