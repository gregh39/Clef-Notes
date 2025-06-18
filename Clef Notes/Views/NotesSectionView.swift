//
//  NotesSectionView.swift
//  Clef Notes
//
//  Created by Greg Holland on 6/13/25.
//
import SwiftUI
import SwiftData

struct NotesSectionView: View {
    @Bindable var session: PracticeSession
    @Binding var editingNote: Note?
    @Binding var showingAddNoteSheet: Bool
    @Environment(\.modelContext) private var context

    var body: some View {
        Section("Notes") {
            if session.notes.isEmpty {
                Text("No notes")
                    .foregroundColor(.secondary)
            } else {
                ForEach(session.notes, id: \.persistentModelID) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        if !note.songs.isEmpty {
                            Text(note.songs.map { $0.title }.joined(separator: ", "))
                                .font(.headline)
                        }
                        Text(note.text)
                    }
                    .onTapGesture {
                        DispatchQueue.main.async {
                            editingNote = note
                            showingAddNoteSheet = true
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let note = session.notes[index]
                        context.delete(note)
                        session.notes.remove(at: index)
                    }
                    try? context.save()
                }
            }
        }
    }
}
