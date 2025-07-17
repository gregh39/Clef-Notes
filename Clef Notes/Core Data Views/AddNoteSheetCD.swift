import SwiftUI
import CoreData

struct AddNoteSheetCD: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var note: NoteCD

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SongCD.title, ascending: true)])
    private var songs: FetchedResults<SongCD>

    // Local state for editing
    @State private var noteText: String = ""
    @State private var drawingData: Data = Data()
    @State private var taggedSongs: Set<SongCD> = []

    @State private var showSketchArea: Bool
    @State private var selectedDetent: PresentationDetent

    init(note: NoteCD) {
        self.note = note
        let hasDrawing = !(note.drawing?.isEmpty ?? true)
        _showSketchArea = State(initialValue: hasDrawing)
        _selectedDetent = State(initialValue: hasDrawing ? .large : .medium)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Enter note text", text: $noteText, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Button(showSketchArea ? "Hide Sketch" : "Add Sketch") {
                        withAnimation {
                            showSketchArea.toggle()
                            selectedDetent = showSketchArea ? .large : .medium
                        }
                    }
                }
                
                if showSketchArea {
                    Section("Sketch") {
                        DrawingView(drawingData: $drawingData)
                            .frame(height: 400)
                            .cornerRadius(10)
                    }
                }

                Section("Tag Songs") {
                    Picker("Add Song", selection: Binding<SongCD?>(get: { nil }, set: { selected in
                        if let song = selected {
                            taggedSongs.insert(song)
                        }
                    })) {
                        Text("Select a song...").tag(Optional<SongCD>.none)
                        ForEach(songs) { song in
                            Text(song.title ?? "Unknown").tag(Optional(song))
                        }
                    }
                    
                    ForEach(Array(taggedSongs)) { taggedSong in
                        HStack {
                            Text(taggedSong.title ?? "Unknown")
                            Spacer()
                            Button(role: .destructive) {
                                taggedSongs.remove(taggedSong)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Edit Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        note.text = noteText
                        note.drawing = drawingData
                        note.songs = NSSet(array: Array(taggedSongs))
                        
                        try? viewContext.save()
                        dismiss()
                    }
                }
            }
            .presentationDetents([.medium, .large], selection: $selectedDetent)
            .onAppear {
                noteText = note.text ?? ""
                drawingData = note.drawing ?? Data()
                taggedSongs = note.songs as? Set<SongCD> ?? []
            }
        }
    }
}
