//
//  NotesSectionViewCD.swift
//  Clef Notes
//
//  Created by Greg Holland on 7/16/25.
//


import SwiftUI
import CoreData

struct NotesSectionViewCD: View {
    @ObservedObject var session: PracticeSessionCD
    @Binding var editingNote: NoteCD?
    @Binding var showingAddNoteSheet: Bool
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        Section("Session Notes") {
            if session.notesArray.isEmpty {
                Button(action: {
                    let note = NoteCD(context: viewContext)
                    note.text = ""
                    session.addToNotes(note)
                    note.student = session.student // Add this line
                    editingNote = note
                    showingAddNoteSheet = true
                }) {
                    Label("Add Note", systemImage: "note.text.badge.plus")
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            } else {
                ForEach(session.notesArray) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        if !note.songsArray.isEmpty {
                            Text(note.songsArray.map { $0.title ?? "" }.joined(separator: ", "))
                                .font(.headline)
                        }
                        Text(note.text ?? "")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingNote = note
                        showingAddNoteSheet = true
                    }
                }
                .onDelete(perform: deleteNote)
                
                Button(action: {
                    let note = NoteCD(context: viewContext)
                    note.text = ""
                    session.addToNotes(note)
                    note.student = session.student // And add this line here too
                    editingNote = note
                    showingAddNoteSheet = true
                }) {
                    Label("Add Note", systemImage: "note.text.badge.plus")
                }
            }
        }
    }
    
    private func deleteNote(at offsets: IndexSet) {
        for index in offsets {
            let noteToDelete = session.notesArray[index]
            viewContext.delete(noteToDelete)
        }
        try? viewContext.save()
    }
}
