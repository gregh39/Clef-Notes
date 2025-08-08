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
            .navigationTitle("Notes")
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

private struct NoteCell: View {

    @ObservedObject var note: NoteCD

    var onTap: () -> Void

    var body: some View {

        Button(action: onTap) {

            HStack(alignment: .center, spacing: 15) {

                VStack {

                    if let drawingData = note.drawing, !drawingData.isEmpty,

                       let drawing = try? PKDrawing(data: drawingData) {

                        Image(uiImage: drawing.image(from: drawing.bounds, scale: UIScreen.main.scale))

                            .resizable()

                            .scaledToFit()

                            .frame(width: 40, height: 40)

                            .background(Color(UIColor.systemBackground))

                            .clipShape(RoundedRectangle(cornerRadius: 6))

                            .overlay(

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
