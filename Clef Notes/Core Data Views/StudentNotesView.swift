import SwiftUI
import CoreData
import PencilKit

struct StudentNotesView: View {
    @ObservedObject var student: StudentCD
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest private var notes: FetchedResults<NoteCD>

    @State private var noteToEdit: NoteCD?
    @Binding var triggerAddNote: Bool
    
    @State private var path = NavigationPath()


    private var generalNotes: [NoteCD] {
        notes.filter { $0.session?.day == nil && $0.date == nil }
    }

    private var groupedDatedNotes: [NoteGroup] {
        let datedNotes = notes.filter { $0.session?.day != nil || $0.date != nil }

        let grouped = Dictionary(grouping: datedNotes) { note -> Date in
            let dateToUse = note.session?.day ?? note.date!
            return Calendar.current.startOfDay(for: dateToUse)
        }
        return grouped.map { NoteGroup(date: $0, notes: $1) }.sorted { $0.date > $1.date }
    }

    init(student: StudentCD, triggerAddNote: Binding<Bool>) {
        self.student = student
        self._triggerAddNote = triggerAddNote
        self._notes = FetchRequest<NoteCD>(
            sortDescriptors: [],
            predicate: NSPredicate(format: "student == %@", student)
        )
    }

    var body: some View {
        // --- THIS IS THE FIX: Changed list style to .insetGrouped for consistency ---
        NavigationStack(path: $path) {
            List {
                if notes.isEmpty {
                    ContentUnavailableView {
                        Label("No Notes Yet", systemImage: "note.text.badge.plus")
                    } description: {
                        Text("Tap the '+' button in the navigation bar to add a general note for this student.")
                    }
                } else {
                    if !generalNotes.isEmpty {
                        Section("General Notes") {
                            ForEach(generalNotes) { note in
                                NoteCell(note: note) { self.noteToEdit = note }
                            }
                            .onDelete(perform: deleteGeneralNote)
                        }
                    }
                    
                    ForEach(groupedDatedNotes) { group in
                        Section(header: Text(group.date, style: .date)) {
                            ForEach(group.notes) { note in
                                NoteCell(note: note) { self.noteToEdit = note }
                            }
                            .onDelete { indexSet in
                                deleteDatedNote(at: indexSet, from: group.notes)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .sheet(item: $noteToEdit) { note in
                AddNoteSheetCD(note: note)
            }
            .onChange(of: triggerAddNote) {
                if triggerAddNote {
                    addNote()
                    triggerAddNote = false
                }
            }
            .navigationTitle("Notes")
        }
    }

    private func addNote() {
        let newNote = NoteCD(context: viewContext)
        newNote.student = student
        newNote.date = .now
        noteToEdit = newNote
    }
    
    private func deleteGeneralNote(at offsets: IndexSet) {
        for index in offsets {
            let noteToDelete = generalNotes[index]
            viewContext.delete(noteToDelete)
        }
        try? viewContext.save()
    }
    
    private func deleteDatedNote(at offsets: IndexSet, from notes: [NoteCD]) {
        for index in offsets {
            let noteToDelete = notes[index]
            viewContext.delete(noteToDelete)
        }
        try? viewContext.save()
    }
}

private struct NoteCell: View {

    @ObservedObject var note: NoteCD

    var onTap: () -> Void

    var body: some View {

        Button(action: onTap) {

            HStack(alignment: .center, spacing: 15) {

                VStack {

                    // --- THIS IS THE FIX: Correctly render the drawing thumbnail ---

                    if let drawingData = note.drawing, !drawingData.isEmpty,

                       let drawing = try? PKDrawing(data: drawingData) {

                        // Generate image with a non-transparent background

                        Image(uiImage: drawing.image(from: drawing.bounds, scale: UIScreen.main.scale))

                            .resizable()

                            .scaledToFit()

                            .frame(width: 40, height: 40)

                            .background(Color(UIColor.systemBackground)) // Use system background for adaptability

                            .clipShape(RoundedRectangle(cornerRadius: 6)) // Clip the image content

                            .overlay( // Add border on top of the clipped shape

                                RoundedRectangle(cornerRadius: 6)

                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)

                            )

                    } else {

                        Image(systemName: "doc.text.fill")

                            .font(.system(size: 24))

                            .frame(width: 40, height: 40)

                            .background(Color.accentColor.opacity(0.1))

                            .foregroundColor(.accentColor)

                            .cornerRadius(6)

                    }

                }

  

                VStack(alignment: .leading, spacing: 5) {

                    if !note.songsArray.isEmpty {

                        Text(note.songsArray.map { $0.title ?? "" }.joined(separator: ", "))

                            .font(.caption.weight(.bold))

                            .foregroundColor(.secondary)

                            .lineLimit(1)

                    }

                    if let text = note.text, !text.isEmpty {

                        Text(text)

                            .font(.body)

                            .foregroundColor(.primary)

                            .lineLimit(2)

                    } else if note.drawing == nil || note.drawing!.isEmpty {

                        Text("Empty Note")

                            .font(.body)

                            .foregroundColor(.secondary)

                    } else {

                        Text("Sketch")

                            .font(.body)

                            .foregroundColor(.secondary)

                    }

                }

                Spacer()

                // --- THIS IS THE FIX: Removed the chevron arrow ---

            }

            .padding(12)

            .background(Color(UIColor.secondarySystemGroupedBackground))

            .cornerRadius(12)

        }

        .buttonStyle(.plain)

        .listRowSeparator(.hidden)

        .listRowInsets(EdgeInsets())

    }

}

private struct NoteGroup: Identifiable {
    var id: Date { date }
    let date: Date
    let notes: [NoteCD]
}
