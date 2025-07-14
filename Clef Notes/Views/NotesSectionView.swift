import SwiftUI
import SwiftData

struct NotesSectionView: View {
    @Bindable var session: PracticeSession
    @Binding var editingNote: Note?
    @Binding var showingAddNoteSheet: Bool
    @Environment(\.modelContext) private var context

    var body: some View {
        Section("Session Notes") {
            // ReusableNotesView now only displays the list of existing notes.
            ReusableNotesView(
                notes: session.notes ?? [],
                onDelete: { indexSet in
                    // Logic for deleting a note from a SESSION.
                    for index in indexSet {
                        if let noteToDelete = session.notes?[index] {
                            context.delete(noteToDelete)
                        }
                    }
                    session.notes?.remove(atOffsets: indexSet)
                    try? context.save()
                },
                onEdit: { note in
                    // Logic for editing a note.
                    editingNote = note
                    showingAddNoteSheet = true
                }
            )
            
            // --- THIS IS THE FIX ---
            // A separate button is added back to handle note creation.
            Button(action: {
                // This is the logic for adding a note to a SESSION.
                let note = Note(text: "")
                note.session = session
                session.notes?.append(note)
                context.insert(note)
                editingNote = note
                showingAddNoteSheet = true
            }) {
                Label("Add Note", systemImage: "note.text.badge.plus")
            }
        }
    }
}
