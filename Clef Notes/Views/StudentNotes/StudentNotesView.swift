import SwiftUI
import CoreData
import PencilKit

struct StudentNotesView: View {
    @ObservedObject var student: StudentCD
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest private var notes: FetchedResults<NoteCD>

    @State private var noteToEdit: NoteCD?
    @Binding var triggerAddNote: Bool
    
    @State private var searchText = ""
    @State private var path = NavigationPath()

    private var filteredNotes: [NoteCD] {
        if searchText.isEmpty {
            return Array(notes)
        } else {
            return notes.filter { note in
                let searchTextLowercased = searchText.lowercased()
                
                if let text = note.text, text.lowercased().contains(searchTextLowercased) {
                    return true
                }
                
                for song in note.songsArray {
                    if let title = song.title, title.lowercased().contains(searchTextLowercased) {
                        return true
                    }
                }
                
                return false
            }
        }
    }

    private var generalNotes: [NoteCD] {
        filteredNotes.filter { $0.session?.day == nil && $0.date == nil }
    }

    private var groupedDatedNotes: [NoteGroup] {
        let datedNotes = filteredNotes.filter { $0.session?.day != nil || $0.date != nil }

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
            sortDescriptors: [NSSortDescriptor(keyPath: \NoteCD.date, ascending: false)],
            predicate: NSPredicate(format: "student == %@", student)
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if notes.isEmpty {
                    ContentUnavailableView {
                        Label("No Notes Yet", systemImage: "note.text.badge.plus")
                    } description: {
                        Text("Tap the '+' button in the navigation bar to add a general note for this student.")
                    } actions: {
                        Button("Add First Note", action: addNote)
                            .buttonStyle(.borderedProminent)
                    }
                } else if filteredNotes.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    noteList
                }
            }
            .sheet(item: $noteToEdit) { note in
                if #available(iOS 18.0, *) {
                    AddNoteSheetCD(note: note)
                        .presentationSizing(.page)
                } else {
                    AddNoteSheetCD(note: note)
                }
            }
            .onChange(of: triggerAddNote) {
                if triggerAddNote {
                    addNote()
                    triggerAddNote = false
                }
            }
            .searchable(text: $searchText, prompt: "Search Notes and Songs")
        }
    }

    private var noteList: some View {
        List {
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
        .listStyle(.insetGrouped)
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


private struct NoteGroup: Identifiable {
    var id: Date { date }
    let date: Date
    let notes: [NoteCD]
}
