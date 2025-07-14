import SwiftUI
import SwiftData

// A generic, reusable view for displaying a list of notes.
struct ReusableNotesView: View {
    // It accepts any collection of notes.
    let notes: [Note]
    
    // It uses closures to communicate user actions back to the parent view.
    // --- The onAdd closure has been removed ---
    var onDelete: (IndexSet) -> Void
    var onEdit: (Note) -> Void

    var body: some View {
        // Display the notes that were passed in.
        ForEach(notes) { note in
            VStack(alignment: .leading, spacing: 4) {
                // Show tagged songs, if any.
                if let songs = note.songs, !songs.isEmpty {
                    Text(songs.map { $0.title }.joined(separator: ", "))
                        .font(.headline)
                }
                Text(note.text)
            }
            .contentShape(Rectangle()) // Make the whole area tappable
            .onTapGesture {
                onEdit(note) // Let the parent view handle editing.
            }
        }
        .onDelete(perform: onDelete) // Let the parent view handle deletion.
        
        // --- The "Add Note" button has been removed from this view ---
    }
}
